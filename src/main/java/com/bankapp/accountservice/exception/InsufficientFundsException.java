package com.bankapp.accountservice.exception;

/**
 * Thrown when a withdrawal is attempted for an amount greater than the
 * current account balance.
 */
public class InsufficientFundsException extends RuntimeException {

    public InsufficientFundsException(String message) {
        super(message);
    }
}
