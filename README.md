# Account Service — Banking Microservice

A production-grade Spring Boot 3 / Java 21 microservice for managing bank
accounts (creation, thread-safe deposits and withdrawals), built with a
security-first DevSecOps pipeline.

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml                # Build, swappable SAST, container scan, publish, swappable deploy
├── charts/
│   └── account-service/              # Helm chart for the kubernetes-helm deploy target
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── serviceaccount.yaml
│           ├── hpa.yaml
│           └── NOTES.txt
├── sonar-project.properties          # Used by the sonarqube SAST option
├── src/
│   ├── main/
│   │   ├── java/com/bankapp/accountservice/
│   │   │   ├── BankingApplication.java
│   │   │   ├── controller/
│   │   │   │   └── AccountController.java
│   │   │   ├── service/
│   │   │   │   ├── AccountService.java
│   │   │   │   └── impl/AccountServiceImpl.java
│   │   │   ├── repository/
│   │   │   │   ├── AccountRepository.java
│   │   │   │   └── impl/InMemoryAccountRepository.java
│   │   │   ├── model/
│   │   │   │   └── Account.java
│   │   │   ├── dto/
│   │   │   │   ├── AccountCreationRequest.java
│   │   │   │   ├── AccountResponse.java
│   │   │   │   └── TransactionRequest.java
│   │   │   └── exception/
│   │   │       ├── GlobalExceptionHandler.java
│   │   │       ├── AccountNotFoundException.java
│   │   │       ├── InsufficientFundsException.java
│   │   │       └── ErrorResponse.java
│   │   └── resources/
│   │       └── application.yml
│   └── test/java/com/bankapp/accountservice/
│       ├── controller/AccountControllerTest.java
│       └── service/AccountServiceImplTest.java
├── Dockerfile
├── .dockerignore
├── .gitignore
└── pom.xml
```

## Architecture

Layered architecture with strict separation of concerns:

- **Controller** (`AccountController`) — HTTP binding, request validation trigger, status codes.
- **Service** (`AccountService` / `AccountServiceImpl`) — business rules (deposit/withdraw semantics).
- **Repository** (`AccountRepository` / `InMemoryAccountRepository`) — persistence abstraction, backed by a `ConcurrentHashMap` demo store.
- **Model** (`Account`) — domain entity; balance mutations are `synchronized` on the instance monitor so concurrent deposit/withdraw calls against the *same* account are serialized without blocking unrelated accounts.
- **DTOs** — `jakarta.validation` annotated records decouple the wire format from the domain model and reject invalid input (negative/zero amounts, blank names, malformed currency codes) before it reaches business logic.
- **GlobalExceptionHandler** — `@RestControllerAdvice` translating domain/validation exceptions into structured JSON errors with correct HTTP status codes, without leaking stack traces to clients.

## API

| Method | Path                                   | Description                    | Success | Failure modes |
|--------|-----------------------------------------|--------------------------------|---------|---------------|
| POST   | `/api/v1/accounts`                      | Create an account              | 201     | 400 (validation) |
| GET    | `/api/v1/accounts`                      | List all accounts              | 200     | — |
| GET    | `/api/v1/accounts/{accountNumber}`      | Get one account                | 200     | 404 (not found) |
| POST   | `/api/v1/accounts/{accountNumber}/deposit`  | Deposit funds               | 200     | 400 (validation), 404 |
| POST   | `/api/v1/accounts/{accountNumber}/withdraw` | Withdraw funds               | 200     | 400 (validation), 404, 409 (insufficient funds) |

Example:

```bash
curl -X POST http://localhost:8080/api/v1/accounts \
  -H 'Content-Type: application/json' \
  -d '{"accountHolderName":"Ada Lovelace","openingBalance":100.00,"currency":"USD"}'
```

## Build & Test

```bash
mvn clean verify
```

Runs unit tests (including a concurrency test that hammers a single account
from 50 parallel threads to validate thread-safety) and packages
`target/account-service.jar`.

Run locally:

```bash
java -jar target/account-service.jar
```

Optional dependency vulnerability scan (OWASP dependency-check, not run by default):

```bash
mvn -Psecurity-scan verify
```

## Container

Multi-stage, non-root image based on `eclipse-temurin:21-jre-alpine`:

```bash
docker build -t account-service:local .
docker run -p 8080:8080 account-service:local
```

The final stage runs as a dedicated unprivileged `bankapp` user/group (uid/gid 1000),
uses Spring Boot's layered jar extraction for optimal Docker layer caching, and
exposes a container `HEALTHCHECK` against `/actuator/health`.

## CI/CD Pipeline (`.github/workflows/ci-cd.yml`)

This pipeline is built as a **DevSecOps playground**: the SAST tool and the
deploy target are runtime switches, not hard-coded choices, so you can swap
tools/targets without editing the workflow file.

Triggered on push/PR to `main`, or manually via **Actions → CI/CD Pipeline →
Run workflow**, which exposes three inputs:

| Input | Options | Default | Effect |
|---|---|---|---|
| `sast_tool` | `semgrep`, `sonarqube`, `fortify`, `all` | `semgrep` | Which SAST tool(s) run. `all` runs every tool so you can compare results side by side in the Security tab (each uploads under its own SARIF category). |
| `deploy_target` | `ec2-basic`, `kubernetes-helm`, `none` | `ec2-basic` | Where the verified image is deployed after publish. |
| `fail_on_sast_findings` | `true`, `false` | `false` | Whether SAST findings block the pipeline (container-scan gating via Trivy is unaffected and always enforced). |

For ordinary push/PR runs (no manual inputs available), the same defaults
apply unless you set repo **Variables** (Settings → Secrets and variables →
Actions → Variables): `DEFAULT_SAST_TOOL`, `DEFAULT_DEPLOY_TARGET`,
`DEFAULT_FAIL_ON_SAST`. This lets you change what "normal" CI runs do without
touching the workflow file.

### Stages

1. **Build & Test** — JDK 21 + Maven cache, unit tests, package.
2. **SAST** (`sast-scan` job) — runs whichever tool(s) `SAST_TOOL` selects:
   - `semgrep` — `pip install semgrep`, `semgrep scan --config auto`, no license required. Good default for a quick, free signal.
   - `sonarqube` — `sonarsource/sonarqube-scan-action`, works against a self-hosted SonarQube server or SonarCloud via `SONAR_HOST_URL`/`SONAR_TOKEN`; reads `sonar-project.properties` and the JaCoCo XML report produced by `mvn verify`.
   - `fortify` — Fortify Static Code Analyzer via the official `fortify/github-action`, importing results into the Security tab.
   - `all` — runs all three.
3. **Container Build & Scan** — GHCR login, local Docker build, Trivy scan (SARIF uploaded to the Security tab, then a second run **always** fails the build on any `HIGH`/`CRITICAL` finding — this gate is not a playground switch, it's a hard baseline).
4. **Publish** — verified image pushed to GHCR tagged with the commit SHA (and `latest`) — `main` only.
5. **Deploy** — whichever job matches `deploy_target`:
   - `ec2-basic` (`deploy-ec2-basic` job) — runs on **your own self-hosted runner** (see below), does `docker pull` + stop/remove + `docker run` directly on the box, then smoke-tests `/actuator/health`. No SSH keys needed since the runner *is* the EC2 instance.
   - `kubernetes-helm` (`deploy-kubernetes-helm` job) — `helm upgrade --install` using the chart at `charts/account-service` against a cluster reachable via a kubeconfig secret.
   - `none` — skip deploy entirely (useful when you only want to compare SAST/scan output).

### Setting up the EC2 self-hosted runner (for `ec2-basic`)

On the EC2 box:

```bash
# From: Settings > Actions > Runners > New self-hosted runner (copy the exact
# download/config commands GitHub gives you; the labels matter):
./config.sh --url https://github.com/fir36/java-app \
            --token <runner-registration-token> \
            --labels ec2,linux
./svc.sh install
./svc.sh start
```

The runner needs Docker installed and the runner's user added to the
`docker` group. The workflow's `deploy-ec2-basic` job targets
`runs-on: [self-hosted, ec2, linux]` — match those labels when registering.

### Required secrets/environments

| Secret | Scope | Purpose |
|---|---|---|
| `SONAR_TOKEN`, `SONAR_HOST_URL` | Repo or Organization | `sast_tool=sonarqube` |
| `FORTIFY_SSC_URL`, `FORTIFY_SSC_TOKEN`, `FORTIFY_LICENSE` | Organization | `sast_tool=fortify` |
| `KUBE_CONFIG_BASE64` | `production` environment | `deploy_target=kubernetes-helm` |
| `GITHUB_TOKEN` | Built-in | GHCR auth (no setup needed) |

`semgrep` and `ec2-basic` need no secrets at all — they're the zero-config
path for trying the pipeline end to end.

### Deploying with Helm directly (outside the pipeline)

```bash
helm upgrade --install account-service ./charts/account-service \
  --namespace banking --create-namespace \
  --set image.repository=ghcr.io/fir36/java-app \
  --set image.tag=<sha-or-tag>
```

## Security Notes

- Input validation via `jakarta.validation` rejects negative/zero transaction amounts and negative opening balances at the boundary.
- Errors never leak stack traces or internal messages (`server.error.include-stacktrace: never`).
- Actuator only exposes `health`/`info`; health details are hidden (`show-details: never`).
- Container runs as non-root; base image patched at build time (`apk upgrade`).
- Registry auth, kubeconfig, and SAST tool credentials are all externalized as GitHub secrets, never committed.
- The Helm chart runs the container as non-root (`runAsNonRoot`, drops all Linux capabilities) and disables privilege escalation, mirroring the Dockerfile's own non-root user.
