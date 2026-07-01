package com.bankapp.accountservice.exception;

import java.time.Instant;
import java.util.Map;

/**
 * Standard error envelope returned to API clients.
 *
 * <p>Deliberately excludes stack traces and internal exception messages for
 * unexpected failures to avoid leaking implementation details
 * (OWASP A05:2021 - Security Misconfiguration / information exposure).
 */
public record ErrorResponse(
        Instant timestamp,
        int status,
        String error,
        String message,
        String path,
        Map<String, String> validationErrors
) {
    public ErrorResponse(int status, String error, String message, String path) {
        this(Instant.now(), status, error, message, path, null);
    }

    public ErrorResponse(int status, String error, String message, String path, Map<String, String> validationErrors) {
        this(Instant.now(), status, error, message, path, validationErrors);
    }
}
