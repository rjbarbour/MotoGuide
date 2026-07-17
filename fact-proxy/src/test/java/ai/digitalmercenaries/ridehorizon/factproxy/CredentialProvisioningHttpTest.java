package ai.digitalmercenaries.ridehorizon.factproxy;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "ridehorizon.proxy-token=operator-proxy-token",
        "ridehorizon.admin-token=operator-admin-token",
        "openai.api-key=test-key",
        "spring.datasource.url=jdbc:h2:mem:credential-provisioning;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.datasource.driver-class-name=org.h2.Driver"
})
class CredentialProvisioningHttpTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @org.springframework.boot.test.mock.mockito.MockBean
    private OpenAiService openAiService;

    @Test
    void invitedDeviceCanObtainCredentialAndCallProtectedEndpoint() throws Exception {
        when(openAiService.generateFact(any())).thenReturn("Known for its wool trade.");

        String inviteJson = mockMvc.perform(post("/admin/v1/invites")
                        .header("Authorization", "Bearer operator-admin-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"label\":\"alpha rider\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        JsonNode invite = objectMapper.readTree(inviteJson);

        String credentialJson = mockMvc.perform(post("/v1/provision")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ProvisionRequest(
                                invite.path("inviteCode").asText(),
                                "test-device-0001"
                        ))))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        JsonNode credential = objectMapper.readTree(credentialJson);

        mockMvc.perform(post("/v1/fact")
                        .header("Authorization", "Bearer " + credential.path("credential").asText())
                        .header("X-RideHorizon-Device-Id", "test-device-0001")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(FactRequestFixture.shortFactRequestWithDefaults()))
                .andExpect(status().isOk());
    }

    @Test
    void inviteCannotBeRedeemedTwice() throws Exception {
        String inviteJson = mockMvc.perform(post("/admin/v1/invites")
                        .header("Authorization", "Bearer operator-admin-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"label\":\"single use\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String inviteCode = objectMapper.readTree(inviteJson).path("inviteCode").asText();
        String request = objectMapper.writeValueAsString(new ProvisionRequest(inviteCode, "test-device-0002"));

        mockMvc.perform(post("/v1/provision").contentType(MediaType.APPLICATION_JSON).content(request))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/v1/provision").contentType(MediaType.APPLICATION_JSON).content(request))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void administratorCanRevokeIssuedCredential() throws Exception {
        String inviteJson = mockMvc.perform(post("/admin/v1/invites")
                        .header("Authorization", "Bearer operator-admin-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"label\":\"revocation test\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String credentialJson = mockMvc.perform(post("/v1/provision")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ProvisionRequest(
                                objectMapper.readTree(inviteJson).path("inviteCode").asText(),
                                "test-device-0003"))))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        JsonNode issued = objectMapper.readTree(credentialJson);

        mockMvc.perform(delete("/admin/v1/credentials/{credentialId}", issued.path("credentialId").asText())
                        .header("Authorization", "Bearer operator-admin-token"))
                .andExpect(status().isNoContent());

        mockMvc.perform(post("/v1/fact")
                        .header("Authorization", "Bearer " + issued.path("credential").asText())
                        .header("X-RideHorizon-Device-Id", "test-device-0003")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(FactRequestFixture.shortFactRequestWithDefaults()))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void concurrentRedemptionIssuesExactlyOneCredential() throws Exception {
        String inviteJson = mockMvc.perform(post("/admin/v1/invites")
                        .header("Authorization", "Bearer operator-admin-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"label\":\"concurrency test\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String inviteCode = objectMapper.readTree(inviteJson).path("inviteCode").asText();
        String request = objectMapper.writeValueAsString(new ProvisionRequest(inviteCode, "concurrent-device"));
        CountDownLatch start = new CountDownLatch(1);

        try (var executor = Executors.newFixedThreadPool(2)) {
            var first = executor.submit(() -> redeemAfter(start, request));
            var second = executor.submit(() -> redeemAfter(start, request));
            start.countDown();

            List<Integer> statuses = List.of(first.get(), second.get());
            org.junit.jupiter.api.Assertions.assertEquals(1, statuses.stream().filter(code -> code == 201).count());
            org.junit.jupiter.api.Assertions.assertEquals(1, statuses.stream().filter(code -> code == 401).count());
        }
    }

    private int redeemAfter(CountDownLatch start, String request) throws Exception {
        start.await();
        return mockMvc.perform(post("/v1/provision")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andReturn().getResponse().getStatus();
    }

    private record ProvisionRequest(String inviteCode, String deviceId) {
    }
}
