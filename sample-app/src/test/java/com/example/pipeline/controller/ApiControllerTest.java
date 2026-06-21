package com.example.pipeline.controller;

import com.example.pipeline.service.GreetingService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.bean.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.*;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Unit tests for ApiController using MockMvc.
 * Tests all REST endpoints for correct response status, content type, and body.
 */
@WebMvcTest(ApiController.class)
class ApiControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private GreetingService greetingService;

    @Nested
    @DisplayName("GET /api/hello")
    class HelloEndpoint {

        @Test
        @DisplayName("should return default greeting with 200 OK")
        void shouldReturnDefaultGreeting() throws Exception {
            when(greetingService.getGreeting())
                    .thenReturn("Hello from the Dynamic CI/CD Pipeline!");

            mockMvc.perform(get("/api/hello"))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.message", is("Hello from the Dynamic CI/CD Pipeline!")))
                    .andExpect(jsonPath("$.timestamp", notNullValue()));
        }
    }

    @Nested
    @DisplayName("GET /api/hello/{name}")
    class PersonalizedHelloEndpoint {

        @Test
        @DisplayName("should return personalized greeting for given name")
        void shouldReturnPersonalizedGreeting() throws Exception {
            when(greetingService.getPersonalizedGreeting("jenkins"))
                    .thenReturn("Hello, Jenkins! Welcome to the Dynamic CI/CD Pipeline!");

            mockMvc.perform(get("/api/hello/jenkins"))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.message", is("Hello, Jenkins! Welcome to the Dynamic CI/CD Pipeline!")))
                    .andExpect(jsonPath("$.timestamp", notNullValue()));
        }
    }

    @Nested
    @DisplayName("GET /api/info")
    class InfoEndpoint {

        @Test
        @DisplayName("should return application info with all expected fields")
        void shouldReturnAppInfo() throws Exception {
            mockMvc.perform(get("/api/info"))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.application", is("Pipeline Demo Application")))
                    .andExpect(jsonPath("$.version", notNullValue()))
                    .andExpect(jsonPath("$.environment", notNullValue()))
                    .andExpect(jsonPath("$.deploymentColor", notNullValue()))
                    .andExpect(jsonPath("$.timestamp", notNullValue()));
        }
    }

    @Nested
    @DisplayName("GET /api/health")
    class HealthEndpoint {

        @Test
        @DisplayName("should return UP status")
        void shouldReturnHealthStatus() throws Exception {
            mockMvc.perform(get("/api/health"))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status", is("UP")))
                    .andExpect(jsonPath("$.service", is("pipeline-demo-app")));
        }
    }

    @Nested
    @DisplayName("GET /api/ready")
    class ReadinessEndpoint {

        @Test
        @DisplayName("should return READY status")
        void shouldReturnReadinessStatus() throws Exception {
            mockMvc.perform(get("/api/ready"))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status", is("READY")));
        }
    }
}
