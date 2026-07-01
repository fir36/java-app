# syntax=docker/dockerfile:1

#######################################
# Stage 1: Build the application with Maven
#######################################
FROM maven:3.9.9-eclipse-temurin-21-alpine AS build

WORKDIR /build

# Copy only the POM first so dependency resolution is cached in its own
# Docker layer and only re-runs when pom.xml actually changes.
COPY pom.xml .
RUN mvn -B dependency:go-offline

COPY src ./src
RUN mvn -B clean package -DskipTests

#######################################
# Stage 2: Explode the fat jar into layers
#######################################
FROM eclipse-temurin:21-jre-alpine AS layers

WORKDIR /application
COPY --from=build /build/target/account-service.jar application.jar
RUN java -Djarmode=layertools -jar application.jar extract

#######################################
# Stage 3: Minimal, non-root runtime image
#######################################
FROM eclipse-temurin:21-jre-alpine

# Patch OS packages to pick up upstream security fixes not yet baked into
# the base image tag, then drop the package cache to keep the image small.
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*

# Run as a dedicated, unprivileged, non-login system user/group instead of
# root (OWASP/CIS Docker Benchmark: containers must not run as root).
RUN addgroup -S -g 1000 bankapp \
    && adduser -S -u 1000 -G bankapp -H -D -s /sbin/nologin bankapp

WORKDIR /application

# Copy exploded layers in increasing order of change frequency so that
# rebuilding only the application code reuses cached dependency layers.
COPY --from=layers --chown=bankapp:bankapp /application/dependencies/ ./
COPY --from=layers --chown=bankapp:bankapp /application/spring-boot-loader/ ./
COPY --from=layers --chown=bankapp:bankapp /application/snapshot-dependencies/ ./
COPY --from=layers --chown=bankapp:bankapp /application/application/ ./

USER bankapp:bankapp

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/actuator/health || exit 1

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
