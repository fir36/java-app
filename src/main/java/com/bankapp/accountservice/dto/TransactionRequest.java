package com.bankapp.accountservice.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

/**
 * Request payload for a deposit or withdrawal transaction.
 *
 * <p>{@code amount} must be strictly positive (zero or negative values are
 * rejected at the validation layer, before any service logic executes).
 */
public record TransactionRequest(

        @NotNull(message = "amount is required")
        @DecimalMin(value = "0.01", inclusive = true, message = "amount must be greater than zero")
        @Digits(integer = 17, fraction = 2, message = "amount must have at most 2 decimal places")
        BigDecimal amount
) {
}
