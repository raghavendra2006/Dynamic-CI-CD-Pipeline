package com.example.pipeline.service;

import org.springframework.stereotype.Service;

/**
 * Service class for generating greeting messages.
 * Demonstrates proper service layer architecture for testability.
 */
@Service
public class GreetingService {

    private static final String DEFAULT_GREETING = "Hello from the Dynamic CI/CD Pipeline!";
    private static final String PERSONALIZED_TEMPLATE = "Hello, %s! Welcome to the Dynamic CI/CD Pipeline!";

    /**
     * Returns the default greeting message.
     *
     * @return default greeting string
     */
    public String getGreeting() {
        return DEFAULT_GREETING;
    }

    /**
     * Returns a personalized greeting message.
     *
     * @param name the name to include in the greeting
     * @return personalized greeting string
     * @throws IllegalArgumentException if name is null or blank
     */
    public String getPersonalizedGreeting(String name) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("Name must not be null or blank");
        }
        return String.format(PERSONALIZED_TEMPLATE, capitalize(name));
    }

    /**
     * Capitalizes the first letter of a string.
     *
     * @param input the string to capitalize
     * @return capitalized string
     */
    private String capitalize(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }
        return input.substring(0, 1).toUpperCase() + input.substring(1).toLowerCase();
    }
}
