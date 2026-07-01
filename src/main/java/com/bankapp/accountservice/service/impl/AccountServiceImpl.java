package com.bankapp.accountservice.service.impl;

import com.bankapp.accountservice.dto.AccountCreationRequest;
import com.bankapp.accountservice.dto.AccountResponse;
import com.bankapp.accountservice.dto.TransactionRequest;
import com.bankapp.accountservice.exception.AccountNotFoundException;
import com.bankapp.accountservice.model.Account;
import com.bankapp.accountservice.repository.AccountRepository;
import com.bankapp.accountservice.service.AccountService;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class AccountServiceImpl implements AccountService {

    private final AccountRepository accountRepository;

    public AccountServiceImpl(AccountRepository accountRepository) {
        this.accountRepository = accountRepository;
    }

    @Override
    public AccountResponse createAccount(AccountCreationRequest request) {
        String accountNumber = accountRepository.nextAccountNumber();
        Account account = new Account(
                UUID.randomUUID().toString(),
                accountNumber,
                request.accountHolderName(),
                request.openingBalance(),
                request.currency().toUpperCase());

        accountRepository.save(account);
        return AccountResponse.from(account);
    }

    @Override
    public AccountResponse getAccount(String accountNumber) {
        return AccountResponse.from(findAccountOrThrow(accountNumber));
    }

    @Override
    public List<AccountResponse> getAllAccounts() {
        return accountRepository.findAll().stream()
                .map(AccountResponse::from)
                .toList();
    }

    @Override
    public AccountResponse deposit(String accountNumber, TransactionRequest request) {
        Account account = findAccountOrThrow(accountNumber);
        account.deposit(request.amount());
        return AccountResponse.from(account);
    }

    @Override
    public AccountResponse withdraw(String accountNumber, TransactionRequest request) {
        Account account = findAccountOrThrow(accountNumber);
        account.withdraw(request.amount());
        return AccountResponse.from(account);
    }

    private Account findAccountOrThrow(String accountNumber) {
        return accountRepository.findByAccountNumber(accountNumber)
                .orElseThrow(() -> new AccountNotFoundException("Account not found: " + accountNumber));
    }
}
