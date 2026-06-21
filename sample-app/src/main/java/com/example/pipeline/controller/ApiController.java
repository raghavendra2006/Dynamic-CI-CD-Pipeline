package com.example.pipeline.controller;

import com.example.pipeline.service.GreetingService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * REST API Controller for the Pipeline Demo Application.
 * Provides endpoints for health checks, application info, and greeting services.
 */
@RestController
@RequestMapping("/api")
public class ApiController {

    private final GreetingService greetingService;

    public ApiController(GreetingService greetingService) {
        this.greetingService = greetingService;
    }

    /**
     * Simple hello endpoint to verify the application is running.
     */
    @GetMapping("/hello")
    public ResponseEntity<Map<String, String>> sayHello() {
        Map<String, String> response = new HashMap<>();
        response.put("message", greetingService.getGreeting());
        response.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(response);
    }

    /**
     * Personalized greeting endpoint.
     */
    @GetMapping("/hello/{name}")
    public ResponseEntity<Map<String, String>> sayHelloTo(@PathVariable String name) {
        Map<String, String> response = new HashMap<>();
        response.put("message", greetingService.getPersonalizedGreeting(name));
        response.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(response);
    }

    /**
     * Application information endpoint.
     * Returns version, environment, and deployment metadata.
     */
    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> getInfo() {
        Map<String, Object> info = new HashMap<>();
        info.put("application", "Pipeline Demo Application");
        info.put("version", getAppVersion());
        info.put("environment", System.getenv().getOrDefault("APP_ENVIRONMENT", "development"));
        info.put("deploymentColor", System.getenv().getOrDefault("DEPLOYMENT_COLOR", "unknown"));
        info.put("buildNumber", System.getenv().getOrDefault("BUILD_NUMBER", "local"));
        info.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(info);
    }

    /**
     * Health check endpoint for Kubernetes readiness/liveness probes.
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> health = new HashMap<>();
        health.put("status", "UP");
        health.put("service", "pipeline-demo-app");
        health.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(health);
    }

    /**
     * Readiness check - verifies the application is ready to serve traffic.
     */
    @GetMapping("/ready")
    public ResponseEntity<Map<String, String>> readiness() {
        Map<String, String> readiness = new HashMap<>();
        readiness.put("status", "READY");
        readiness.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(readiness);
    }

    private String getAppVersion() {
        String version = System.getenv("APP_VERSION");
        return version != null ? version : "1.0.0-SNAPSHOT";
    }
}
