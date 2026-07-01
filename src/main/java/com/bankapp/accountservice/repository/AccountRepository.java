package com.bankapp.accountservice.repository;

import com.bankapp.accountservice.model.Account;

import java.util.List;
import java.util.Optional;

/**
 * Persistence abstraction for {@link Account} aggregates.
 *
 * <p>Kept intentionally storage-agnostic so the in-memory demo
 * implementation can later be swapped for a JPA/JDBC-backed one without
 * touching the service layer.
 */
public interface AccountRepository {

    Account save(Account account);

    Optional<Account> findByAccountNumber(String accountNumber);

    List<Account> findAll();

    boolean existsByAccountNumber(String accountNumber);

    String nextAccountNumber();
}
