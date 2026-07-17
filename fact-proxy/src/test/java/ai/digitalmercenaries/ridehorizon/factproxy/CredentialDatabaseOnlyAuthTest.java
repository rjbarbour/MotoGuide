package ai.digitalmercenaries.ridehorizon.factproxy;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "ridehorizon.proxy-token=",
        "ridehorizon.admin-token=operator-admin-token",
        "openai.api-key=test-key",
        "spring.datasource.url=jdbc:h2:mem:database-only-auth;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.datasource.driver-class-name=org.h2.Driver"
})
class CredentialDatabaseOnlyAuthTest {
    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;

    @org.springframework.boot.test.mock.mockito.MockBean
    private OpenAiService openAiService;

    @Test
    void issuedCredentialWorksWithoutSharedProxyToken() throws Exception {
        when(openAiService.generateFact(any())).thenReturn("Known for its wool trade.");
        String invite = mockMvc.perform(post("/admin/v1/invites")
                        .header("Authorization", "Bearer operator-admin-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"label\":\"database only\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String provision = mockMvc.perform(post("/v1/provision")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ProvisionRequest(
                                objectMapper.readTree(invite).path("inviteCode").asText(), "database-device"))))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        mockMvc.perform(post("/v1/fact")
                        .header("Authorization", "Bearer " + objectMapper.readTree(provision).path("credential").asText())
                        .header("X-RideHorizon-Device-Id", "database-device")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(FactRequestFixture.shortFactRequestWithDefaults()))
                .andExpect(status().isOk());
    }

    private record ProvisionRequest(String inviteCode, String deviceId) {}
}
