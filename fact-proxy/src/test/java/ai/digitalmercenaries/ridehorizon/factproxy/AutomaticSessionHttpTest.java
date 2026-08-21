package ai.digitalmercenaries.ridehorizon.factproxy;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "ridehorizon.proxy-token=operator-test-token",
        "ridehorizon.fallback-fact-daily-limit=1",
        "ridehorizon.verified-fact-daily-limit=3",
        "ridehorizon.global-fact-daily-limit=10",
        "spring.datasource.url=jdbc:h2:mem:automatic-session-http;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.datasource.driver-class-name=org.h2.Driver"
})
class AutomaticSessionHttpTest {
    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;

    @MockitoBean private OpenAiService openAiService;
    @MockitoBean private ElevenLabsSpeechService elevenLabsSpeechService;

    @Test
    void automaticSessionRequiresSecureInstallationIdentifier() throws Exception {
        mockMvc.perform(post("/v1/session/fallback")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"automatic\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void automaticSessionAuthenticatesProxyRequestsWithoutUserInput() throws Exception {
        String response = mockMvc.perform(post("/v1/session/fallback")
                        .header("X-RideHorizon-Device-Id", "test-installation-0001")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"automatic\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fallback").value(true))
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode payload = objectMapper.readTree(response);
        String sessionToken = payload.path("sessionToken").asText();
        when(openAiService.generateFactWithMetadata(any())).thenReturn(
                new OpenAiService.GeneratedFact("Known for its wool trade.", null)
        );

        mockMvc.perform(post("/v1/fact")
                        .header("Authorization", "Bearer " + sessionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(FactRequestFixture.shortFactRequestWithDefaults()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fact").value("Known for its wool trade."));
    }

    @Test
    void operatorAccessUsesOperatorQuotaInsteadOfFallbackQuota() throws Exception {
        when(openAiService.generateFactWithMetadata(any())).thenReturn(
                new OpenAiService.GeneratedFact("Known for its wool trade.", null)
        );

        for (int requestNumber = 0; requestNumber < 2; requestNumber++) {
            mockMvc.perform(post("/v1/fact")
                            .header("Authorization", "Bearer operator-test-token")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(FactRequestFixture.shortFactRequestWithDefaults()))
                    .andExpect(status().isOk());
        }
    }
}
