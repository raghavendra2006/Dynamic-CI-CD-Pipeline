package com.example.pipeline.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for GreetingService.
 * Tests greeting generation logic including edge cases.
 */
class GreetingServiceTest {

    private GreetingService greetingService;

    @BeforeEach
    void setUp() {
        greetingService = new GreetingService();
    }

    @Nested
    @DisplayName("getGreeting()")
    class GetGreeting {

        @Test
        @DisplayName("should return default greeting message")
        void shouldReturnDefaultGreeting() {
            String greeting = greetingService.getGreeting();
            assertEquals("Hello from the Dynamic CI/CD Pipeline!", greeting);
        }

        @Test
        @DisplayName("should return non-null greeting")
        void shouldReturnNonNullGreeting() {
            assertNotNull(greetingService.getGreeting());
        }
    }

    @Nested
    @DisplayName("getPersonalizedGreeting()")
    class GetPersonalizedGreeting {

        @Test
        @DisplayName("should return personalized greeting with capitalized name")
        void shouldReturnPersonalizedGreeting() {
            String greeting = greetingService.getPersonalizedGreeting("jenkins");
            assertEquals("Hello, Jenkins! Welcome to the Dynamic CI/CD Pipeline!", greeting);
        }

        @Test
        @DisplayName("should capitalize the first letter of name")
        void shouldCapitalizeName() {
            String greeting = greetingService.getPersonalizedGreeting("kubernetes");
            assertTrue(greeting.contains("Kubernetes"));
        }

        @Test
        @DisplayName("should handle uppercase input")
        void shouldHandleUppercaseInput() {
            String greeting = greetingService.getPersonalizedGreeting("DOCKER");
            assertTrue(greeting.contains("Docker"));
        }

        @Test
        @DisplayName("should throw exception for null name")
        void shouldThrowExceptionForNullName() {
            assertThrows(IllegalArgumentException.class,
                    () -> greetingService.getPersonalizedGreeting(null));
        }

        @Test
        @DisplayName("should throw exception for blank name")
        void shouldThrowExceptionForBlankName() {
            assertThrows(IllegalArgumentException.class,
                    () -> greetingService.getPersonalizedGreeting("   "));
        }

        @Test
        @DisplayName("should throw exception for empty name")
        void shouldThrowExceptionForEmptyName() {
            assertThrows(IllegalArgumentException.class,
                    () -> greetingService.getPersonalizedGreeting(""));
        }
    }
}
