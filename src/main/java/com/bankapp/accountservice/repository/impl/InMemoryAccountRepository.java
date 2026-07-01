package com.bankapp.accountservice.repository.impl;

import com.bankapp.accountservice.model.Account;
import com.bankapp.accountservice.repository.AccountRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Thread-safe in-memory demo persistence store.
 *
 * <p>{@link ConcurrentHashMap} provides safe concurrent access for
 * insertions and lookups; individual {@link Account} instances additionally
 * synchronize their own balance mutations so concurrent deposits/withdrawals
 * against the same account never race.
 */
@Repository
public class InMemoryAccountRepository implements AccountRepository {

    private static final String ACCOUNT_NUMBER_PREFIX = "ACC";

    private final ConcurrentHashMap<String, Account> accountsByNumber = new ConcurrentHashMap<>();
    private final AtomicLong accountNumberSequence = new AtomicLong(1_000_000_000L);

    @Override
    public Account save(Account account) {
        accountsByNumber.put(account.getAccountNumber(), account);
        return account;
    }

    @Override
    public Optional<Account> findByAccountNumber(String accountNumber) {
        return Optional.ofNullable(accountsByNumber.get(accountNumber));
    }

    @Override
    public List<Account> findAll() {
        return List.copyOf(accountsByNumber.values());
    }

    @Override
    public boolean existsByAccountNumber(String accountNumber) {
        return accountsByNumber.containsKey(accountNumber);
    }

    @Override
    public String nextAccountNumber() {
        return ACCOUNT_NUMBER_PREFIX + accountNumberSequence.getAndIncrement();
    }
}
