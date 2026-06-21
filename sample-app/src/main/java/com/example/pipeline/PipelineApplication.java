package com.example.pipeline;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Pipeline Demo Application
 * 
 * A sample Spring Boot application used to demonstrate
 * the Dynamic CI/CD Pipeline with Jenkins on Kubernetes.
 */
@SpringBootApplication
public class PipelineApplication {

    public static void main(String[] args) {
        SpringApplication.run(PipelineApplication.class, args);
    }
}
