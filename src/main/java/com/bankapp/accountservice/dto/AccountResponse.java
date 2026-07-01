package com.bankapp.accountservice.dto;

import com.bankapp.accountservice.model.Account;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Outbound representation of an {@link Account}.
 *
 * <p>Deliberately excludes internal fields not relevant to API consumers and
 * decouples the wire format from the domain model.
 */
public record AccountResponse(
        String id,
        String accountNumber,
        String accountHolderName,
        BigDecimal balance,
        String currency,
        Instant createdAt,
        Instant updatedAt
) {
    public static AccountResponse from(Account account) {
        return new AccountResponse(
                account.getId(),
                account.getAccountNumber(),
                account.getAccountHolderName(),
                account.getBalance(),
                account.getCurrency(),
                account.getCreatedAt(),
                account.getUpdatedAt()
        );
    }
}
