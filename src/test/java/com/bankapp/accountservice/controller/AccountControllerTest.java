package com.bankapp.accountservice.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;

import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class AccountControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void createAccount_validRequest_returns201WithLocationHeader() throws Exception {
        String requestBody = objectMapper.writeValueAsString(
                new CreateAccountPayload("Jane Doe", new BigDecimal("500.00"), "USD"));

        mockMvc.perform(post("/api/v1/accounts")
                        .contentType("application/json")
                        .content(requestBody))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.balance", is(500.00)))
                .andExpect(jsonPath("$.currency", is("USD")));
    }

    @Test
    void createAccount_negativeOpeningBalance_returns400() throws Exception {
        String requestBody = objectMapper.writeValueAsString(
                new CreateAccountPayload("Jane Doe", new BigDecimal("-1.00"), "USD"));

        mockMvc.perform(post("/api/v1/accounts")
                        .contentType("application/json")
                        .content(requestBody))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.validationErrors.openingBalance").exists());
    }

    @Test
    void getAccount_unknownAccountNumber_returns404() throws Exception {
        mockMvc.perform(get("/api/v1/accounts/ACC-UNKNOWN"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status", is(404)));
    }

    @Test
    void deposit_negativeAmount_returns400() throws Exception {
        String createBody = objectMapper.writeValueAsString(
                new CreateAccountPayload("John Smith", new BigDecimal("100.00"), "USD"));

        String response = mockMvc.perform(post("/api/v1/accounts")
                        .contentType("application/json")
                        .content(createBody))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        String accountNumber = objectMapper.readTree(response).get("accountNumber").asText();

        mockMvc.perform(post("/api/v1/accounts/" + accountNumber + "/deposit")
                        .contentType("application/json")
                        .content("{\"amount\": -10.00}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void withdraw_amountExceedsBalance_returns409() throws Exception {
        String createBody = objectMapper.writeValueAsString(
                new CreateAccountPayload("Withdraw Tester", new BigDecimal("20.00"), "USD"));

        String response = mockMvc.perform(post("/api/v1/accounts")
                        .contentType("application/json")
                        .content(createBody))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        String accountNumber = objectMapper.readTree(response).get("accountNumber").asText();

        mockMvc.perform(post("/api/v1/accounts/" + accountNumber + "/withdraw")
                        .contentType("application/json")
                        .content("{\"amount\": 1000.00}"))
                .andExpect(status().isConflict());
    }

    private record CreateAccountPayload(String accountHolderName, BigDecimal openingBalance, String currency) {
    }
}
