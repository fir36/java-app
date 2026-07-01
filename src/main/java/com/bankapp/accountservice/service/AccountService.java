package com.bankapp.accountservice.service;

import com.bankapp.accountservice.dto.AccountCreationRequest;
import com.bankapp.accountservice.dto.AccountResponse;
import com.bankapp.accountservice.dto.TransactionRequest;

import java.util.List;

public interface AccountService {

    AccountResponse createAccount(AccountCreationRequest request);

    AccountResponse getAccount(String accountNumber);

    List<AccountResponse> getAllAccounts();

    AccountResponse deposit(String accountNumber, TransactionRequest request);

    AccountResponse withdraw(String accountNumber, TransactionRequest request);
}
