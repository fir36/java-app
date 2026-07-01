package com.bankapp.accountservice.controller;

import com.bankapp.accountservice.dto.AccountCreationRequest;
import com.bankapp.accountservice.dto.AccountResponse;
import com.bankapp.accountservice.dto.TransactionRequest;
import com.bankapp.accountservice.service.AccountService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.List;

/**
 * REST API for account creation and balance transactions.
 */
@RestController
@RequestMapping("/api/v1/accounts")
public class AccountController {

    private final AccountService accountService;

    public AccountController(AccountService accountService) {
        this.accountService = accountService;
    }

    @PostMapping
    public ResponseEntity<AccountResponse> createAccount(@Valid @RequestBody AccountCreationRequest request,
                                                           UriComponentsBuilder uriComponentsBuilder) {
        AccountResponse response = accountService.createAccount(request);
        return ResponseEntity
                .created(uriComponentsBuilder
                        .path("/api/v1/accounts/{accountNumber}")
                        .buildAndExpand(response.accountNumber())
                        .toUri())
                .body(response);
    }

    @GetMapping
    public ResponseEntity<List<AccountResponse>> getAllAccounts() {
        return ResponseEntity.ok(accountService.getAllAccounts());
    }

    @GetMapping("/{accountNumber}")
    public ResponseEntity<AccountResponse> getAccount(@PathVariable String accountNumber) {
        return ResponseEntity.ok(accountService.getAccount(accountNumber));
    }

    @PostMapping("/{accountNumber}/deposit")
    public ResponseEntity<AccountResponse> deposit(@PathVariable String accountNumber,
                                                    @Valid @RequestBody TransactionRequest request) {
        return ResponseEntity.ok(accountService.deposit(accountNumber, request));
    }

    @PostMapping("/{accountNumber}/withdraw")
    public ResponseEntity<AccountResponse> withdraw(@PathVariable String accountNumber,
                                                     @Valid @RequestBody TransactionRequest request) {
        return ResponseEntity.ok(accountService.withdraw(accountNumber, request));
    }
}
