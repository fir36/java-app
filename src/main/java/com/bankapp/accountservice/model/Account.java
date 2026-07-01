package com.bankapp.accountservice.model;

import com.bankapp.accountservice.exception.InsufficientFundsException;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Domain model for a bank account.
 *
 * <p>Balance mutations ({@link #deposit(BigDecimal)} and
 * {@link #withdraw(BigDecimal)}) are declared {@code synchronized} so that
 * concurrent requests against the same account are serialized on the
 * account's own monitor, guaranteeing thread-safe read-modify-write of the
 * balance without locking unrelated accounts.
 */
public class Account {

    private final String id;
    private final String accountNumber;
    private final String accountHolderName;
    private final String currency;
    private final Instant createdAt;

    private BigDecimal balance;
    private Instant updatedAt;

    public Account(String id,
                    String accountNumber,
                    String accountHolderName,
                    BigDecimal openingBalance,
                    String currency) {
        this.id = id;
        this.accountNumber = accountNumber;
        this.accountHolderName = accountHolderName;
        this.balance = openingBalance;
        this.currency = currency;
        this.createdAt = Instant.now();
        this.updatedAt = this.createdAt;
    }

    public synchronized void deposit(BigDecimal amount) {
        this.balance = this.balance.add(amount);
        this.updatedAt = Instant.now();
    }

    public synchronized void withdraw(BigDecimal amount) {
        if (this.balance.compareTo(amount) < 0) {
            throw new InsufficientFundsException(
                    "Insufficient funds in account " + accountNumber
                            + ": available=" + this.balance + ", requested=" + amount);
        }
        this.balance = this.balance.subtract(amount);
        this.updatedAt = Instant.now();
    }

    public synchronized BigDecimal getBalance() {
        return balance;
    }

    public synchronized Instant getUpdatedAt() {
        return updatedAt;
    }

    public String getId() {
        return id;
    }

    public String getAccountNumber() {
        return accountNumber;
    }

    public String getAccountHolderName() {
        return accountHolderName;
    }

    public String getCurrency() {
        return currency;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
