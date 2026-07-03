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

###############################################################################
# NOTES
###############################################################################
#
# Multi-stage build overview
# --------------------------
# Stage 1 (build)
#   - Uses Maven image to compile the Spring Boot application.
#   - Copies pom.xml first so `mvn dependency:go-offline` can be cached.
#   - If only source code changes, Maven dependencies are NOT downloaded again.
#
# Stage 2 (layers)
#   - Uses Spring Boot Layertools to extract the fat JAR into Docker layers.
#   - Command:
#       java -Djarmode=layertools -jar application.jar extract
#   - Produces:
#       dependencies/
#       spring-boot-loader/
#       snapshot-dependencies/
#       application/
#
# Stage 3 (runtime)
#   - Uses a minimal JRE image.
#   - Does not include Maven or source code.
#   - Runs as a non-root user for better security.
#   - Copies each extracted layer separately.
#
# Why use Layertools?
# -------------------
# Without Layertools:
#
#   application.jar (single layer)
#
#   Any code change -> entire JAR layer is rebuilt.
#
# With Layertools:
#
#   dependencies/
#   spring-boot-loader/
#   snapshot-dependencies/
#   application/
#
#   Only the "application" layer usually changes.
#   Dependency layers are reused from Docker's build cache, making rebuilds
#   much faster.
#
# Docker Cache
# ------------
# Docker stores build layers in its local cache (managed by the Docker daemon).
#
# During rebuild:
#   - Same instruction + same files = cache reused.
#   - Changed files = only that layer and subsequent layers are rebuilt.
#
# Example:
#
#   Change Java code
#      ↓
#   dependencies/          ✔ Reused
#   spring-boot-loader/    ✔ Reused
#   snapshot-dependencies/ ✔ Reused
#   application/           ✘ Rebuilt
#
# Result:
#   Faster builds because large dependency layers don't need to be recreated.
#
###############################################################################

###############################################################################
# ENTRYPOINT EXPLANATION
###############################################################################
#
# Why don't we use:
#
#   java -jar application.jar
#
# Normally, Spring Boot packages everything into a single executable JAR
# (application classes + dependencies + Spring Boot loader), so Java can
# execute it directly.
#
# However, in this Dockerfile we run:
#
#   java -Djarmode=layertools -jar application.jar extract
#
# This extracts the JAR into separate directories:
#
#   dependencies/
#   spring-boot-loader/
#   snapshot-dependencies/
#   application/
#
# The final runtime image no longer contains a single executable JAR.
# Instead, it contains the extracted files copied into /application.
#
# The class:
#
#   org.springframework.boot.loader.launch.JarLauncher
#
# is provided by the spring-boot-loader/ layer. It is Spring Boot's launcher
# class (contains a public static void main() method).
#
# Running:
#
#   java org.springframework.boot.loader.launch.JarLauncher
#
# is effectively the equivalent of:
#
#   java -jar application.jar
#
# JarLauncher automatically:
#   1. Finds the dependency JARs.
#   2. Builds the application classpath.
#   3. Locates the application's Main-Class.
#   4. Starts the Spring Boot application.
#
# Easy way to remember:
#
#   Fat JAR
#       -> java -jar application.jar
#
#   Layered (layertools extract)
#       -> java org.springframework.boot.loader.launch.JarLauncher
#
# Rule of thumb:
# If the application is still packaged as one JAR, use "java -jar".
# If the JAR has been extracted into layers, use Spring Boot's JarLauncher.
#
###############################################################################

# =============================================================================
# SIMPLE DOCKERFILE (REFERENCE ONLY - NOT USED BY BUILD)
# =============================================================================
#
# FROM maven:3.9.9-eclipse-temurin-21-alpine AS build
#
# WORKDIR /build
#
# COPY . .
#
# RUN mvn clean package -DskipTests
#
# FROM eclipse-temurin:21-jre-alpine
#
# WORKDIR /application
#
# COPY --from=build /build/target/account-service.jar application.jar
#
# EXPOSE 8080
#
# ENTRYPOINT ["java", "-jar", "application.jar"]
#
# =============================================================================
# This is the simplified version of the Dockerfile:
# - Builds everything in one Maven step
# - No layer caching optimization
# - Easier to understand
# - Suitable for learning or small projects
# =============================================================================
