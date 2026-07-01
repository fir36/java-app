# Account Service — Banking Microservice

A production-grade Spring Boot 3 / Java 21 microservice for managing bank
accounts (creation, thread-safe deposits and withdrawals), built with a
security-first DevSecOps pipeline.

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml                # Build, SAST, container scan, publish, deploy
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

Triggered on push/PR to `main`:

1. **Build & Test** — JDK 21 + Maven cache, unit tests, package.
2. **SAST** — Fortify Static Code Analyzer (requires org-level `FORTIFY_SSC_URL`, `FORTIFY_SSC_TOKEN`, `FORTIFY_LICENSE` secrets; stubbed with placeholders).
3. **Container Build & Scan** — GHCR login, local Docker build, Trivy scan (SARIF uploaded to the Security tab, then a second run fails the build on any `HIGH`/`CRITICAL` finding).
4. **Publish** — verified image pushed to GHCR tagged with the commit SHA (and `latest`) — main branch only.
5. **Deploy** — Kubernetes rollout stub via `kubectl set image` using a base64-encoded kubeconfig secret, gated behind the `production` GitHub Environment.

### Required secrets/environments before the pipeline is fully live

| Secret | Scope | Purpose |
|---|---|---|
| `FORTIFY_SSC_URL`, `FORTIFY_SSC_TOKEN`, `FORTIFY_LICENSE` | Organization | Fortify SAST |
| `KUBE_CONFIG_BASE64` | `production` environment | Kubernetes deploy stub |
| `GITHUB_TOKEN` | Built-in | GHCR auth (no setup needed) |

## Security Notes

- Input validation via `jakarta.validation` rejects negative/zero transaction amounts and negative opening balances at the boundary.
- Errors never leak stack traces or internal messages (`server.error.include-stacktrace: never`).
- Actuator only exposes `health`/`info`; health details are hidden (`show-details: never`).
- Container runs as non-root; base image patched at build time (`apk upgrade`).
- Registry auth, kubeconfig, and Fortify credentials are all externalized as GitHub secrets, never committed.
