package ai.digitalmercenaries.ridehorizon.factproxy;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "ridehorizon.proxy-token=operator-proxy-token",
        "ridehorizon.admin-token=operator-admin-token",
        "ridehorizon.credential-ttl-days=1",
        "openai.api-key=test-key",
        "spring.datasource.url=jdbc:h2:mem:credential-expiry;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.datasource.driver-class-name=org.h2.Driver"
})
class CredentialExpiryHttpTest {
    private static final Instant ISSUED_AT = Instant.parse("2026-07-17T12:00:00Z");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @org.springframework.boot.test.mock.mockito.MockBean
    private Clock clock;

    @BeforeEach
    void useIssueTime() {
        when(clock.instant()).thenReturn(ISSUED_AT);
        when(clock.getZone()).thenReturn(ZoneOffset.UTC);
    }

    @Test
    void expiredCredentialCannotCallProtectedEndpoint() throws Exception {
        String inviteJson = mockMvc.perform(post("/admin/v1/invites")
                        .header("Authorization", "Bearer operator-admin-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"label\":\"expiry test\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String inviteCode = objectMapper.readTree(inviteJson).path("inviteCode").asText();
        String credentialJson = mockMvc.perform(post("/v1/provision")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ProvisionRequest(inviteCode, "expiry-device"))))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        JsonNode credential = objectMapper.readTree(credentialJson);

        when(clock.instant()).thenReturn(ISSUED_AT.plusSeconds(86_401));

        mockMvc.perform(post("/v1/fact")
                        .header("Authorization", "Bearer " + credential.path("credential").asText())
                        .header("X-RideHorizon-Device-Id", "expiry-device")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(FactRequestFixture.shortFactRequestWithDefaults()))
                .andExpect(status().isUnauthorized());
    }

    private record ProvisionRequest(String inviteCode, String deviceId) {
    }
}
