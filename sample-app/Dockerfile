# =============================================================================
# Multi-Stage Dockerfile for Pipeline Demo Application
# Stage 1: Build with Maven
# Stage 2: Runtime with minimal JRE Alpine image
# =============================================================================

# ----- Stage 1: Build -----
FROM maven:3.9-eclipse-temurin-17 AS builder

WORKDIR /build

# Copy POM first for dependency caching
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests -B

# ----- Stage 2: Runtime -----
FROM eclipse-temurin:17-jre-alpine

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy the built JAR from the builder stage
COPY --from=builder /build/target/pipeline-demo-app.jar app.jar

# Change ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 8080

# Health check using Spring Boot Actuator
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# JVM tuning for container environment
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0"

# Application metadata (set during CI/CD pipeline)
ENV APP_VERSION="1.0.0" \
    APP_ENVIRONMENT="production" \
    DEPLOYMENT_COLOR="unknown" \
    BUILD_NUMBER="local"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
