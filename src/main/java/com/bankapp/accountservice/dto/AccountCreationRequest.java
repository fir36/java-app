package com.bankapp.accountservice.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * Request payload for opening a new bank account.
 */
public record AccountCreationRequest(

        @NotBlank(message = "accountHolderName is required")
        @Size(min = 2, max = 140, message = "accountHolderName must be between 2 and 140 characters")
        String accountHolderName,

        @NotNull(message = "openingBalance is required")
        @DecimalMin(value = "0.0", inclusive = true, message = "openingBalance must not be negative")
        BigDecimal openingBalance,

        @NotBlank(message = "currency is required")
        @Pattern(regexp = "^[A-Z]{3}$", message = "currency must be a 3-letter ISO 4217 code, e.g. USD")
        String currency
) {
}
