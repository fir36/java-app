package com.bankapp.accountservice.service;

import com.bankapp.accountservice.dto.AccountCreationRequest;
import com.bankapp.accountservice.dto.AccountResponse;
import com.bankapp.accountservice.dto.TransactionRequest;
import com.bankapp.accountservice.exception.AccountNotFoundException;
import com.bankapp.accountservice.exception.InsufficientFundsException;
import com.bankapp.accountservice.repository.AccountRepository;
import com.bankapp.accountservice.repository.impl.InMemoryAccountRepository;
import com.bankapp.accountservice.service.impl.AccountServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AccountServiceImplTest {

    private AccountService accountService;

    @BeforeEach
    void setUp() {
        AccountRepository accountRepository = new InMemoryAccountRepository();
        accountService = new AccountServiceImpl(accountRepository);
    }

    @Test
    void createAccount_persistsAndReturnsAccountWithGeneratedNumber() {
        AccountResponse response = accountService.createAccount(
                new AccountCreationRequest("Ada Lovelace", new BigDecimal("100.00"), "USD"));

        assertThat(response.accountNumber()).isNotBlank();
        assertThat(response.balance()).isEqualByComparingTo("100.00");
        assertThat(response.currency()).isEqualTo("USD");
    }

    @Test
    void getAccount_unknownAccountNumber_throwsNotFound() {
        assertThatThrownBy(() -> accountService.getAccount("ACC-DOES-NOT-EXIST"))
                .isInstanceOf(AccountNotFoundException.class);
    }

    @Test
    void deposit_increasesBalance() {
        AccountResponse created = accountService.createAccount(
                new AccountCreationRequest("Grace Hopper", new BigDecimal("50.00"), "USD"));

        AccountResponse afterDeposit = accountService.deposit(
                created.accountNumber(), new TransactionRequest(new BigDecimal("25.50")));

        assertThat(afterDeposit.balance()).isEqualByComparingTo("75.50");
    }

    @Test
    void withdraw_sufficientFunds_decreasesBalance() {
        AccountResponse created = accountService.createAccount(
                new AccountCreationRequest("Alan Turing", new BigDecimal("100.00"), "USD"));

        AccountResponse afterWithdrawal = accountService.withdraw(
                created.accountNumber(), new TransactionRequest(new BigDecimal("40.00")));

        assertThat(afterWithdrawal.balance()).isEqualByComparingTo("60.00");
    }

    @Test
    void withdraw_insufficientFunds_throwsAndLeavesBalanceUnchanged() {
        AccountResponse created = accountService.createAccount(
                new AccountCreationRequest("Katherine Johnson", new BigDecimal("10.00"), "USD"));

        assertThatThrownBy(() -> accountService.withdraw(
                created.accountNumber(), new TransactionRequest(new BigDecimal("10.01"))))
                .isInstanceOf(InsufficientFundsException.class);

        assertThat(accountService.getAccount(created.accountNumber()).balance())
                .isEqualByComparingTo("10.00");
    }

    @Test
    void getAllAccounts_returnsEveryCreatedAccount() {
        accountService.createAccount(new AccountCreationRequest("Holder One", BigDecimal.ZERO, "USD"));
        accountService.createAccount(new AccountCreationRequest("Holder Two", BigDecimal.ZERO, "EUR"));

        List<AccountResponse> all = accountService.getAllAccounts();

        assertThat(all).hasSize(2);
    }

    @Test
    void concurrentDepositsAndWithdrawals_areThreadSafeAndBalanceStaysConsistent() throws InterruptedException {
        AccountResponse created = accountService.createAccount(
                new AccountCreationRequest("Concurrent Tester", new BigDecimal("1000.00"), "USD"));
        String accountNumber = created.accountNumber();

        int threadCount = 50;
        BigDecimal depositAmount = new BigDecimal("10.00");
        BigDecimal withdrawAmount = new BigDecimal("5.00");

        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch latch = new CountDownLatch(threadCount);

        for (int i = 0; i < threadCount; i++) {
            boolean deposit = i % 2 == 0;
            executor.submit(() -> {
                try {
                    if (deposit) {
                        accountService.deposit(accountNumber, new TransactionRequest(depositAmount));
                    } else {
                        accountService.withdraw(accountNumber, new TransactionRequest(withdrawAmount));
                    }
                } finally {
                    latch.countDown();
                }
            });
        }

        assertThat(latch.await(10, TimeUnit.SECONDS)).isTrue();
        executor.shutdown();

        // 25 deposits of 10.00 = +250.00, 25 withdrawals of 5.00 = -125.00
        BigDecimal expectedBalance = new BigDecimal("1000.00").add(new BigDecimal("250.00")).subtract(new BigDecimal("125.00"));
        assertThat(accountService.getAccount(accountNumber).balance()).isEqualByComparingTo(expectedBalance);
    }
}
