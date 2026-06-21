# =============================================================================
# Dockerfile for Pipeline Demo Application
# Runtime image copying pre-built JAR from CI workspace
# =============================================================================

FROM eclipse-temurin:17-jre-alpine

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy the pre-built JAR from the workspace target directory
COPY target/pipeline-demo-app.jar app.jar

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
