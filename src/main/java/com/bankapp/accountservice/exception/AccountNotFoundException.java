package com.bankapp.accountservice.exception;

/**
 * Thrown when a requested account cannot be located.
 */
public class AccountNotFoundException extends RuntimeException {

    public AccountNotFoundException(String message) {
        super(message);
    }
}
