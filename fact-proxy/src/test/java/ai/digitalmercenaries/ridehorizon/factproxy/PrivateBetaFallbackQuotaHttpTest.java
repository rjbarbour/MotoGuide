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
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "spring.datasource.url=jdbc:h2:mem:private-beta-fallback-quota;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.datasource.driver-class-name=org.h2.Driver"
})
class PrivateBetaFallbackQuotaHttpTest {
    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;

    @MockitoBean private OpenAiService openAiService;
    @MockitoBean private ElevenLabsSpeechService elevenLabsSpeechService;

    @Test
    void productionFallbackAllowanceSupportsMoreThanTwentyFactsPerDay() throws Exception {
        String sessionResponse = mockMvc.perform(post("/v1/session/fallback")
                        .header("X-RideHorizon-Device-Id", "private-beta-quota-regression")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"automatic\"}"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode payload = objectMapper.readTree(sessionResponse);
        String sessionToken = payload.path("sessionToken").asText();
        when(openAiService.generateFact(any())).thenReturn("Known for its wool trade.");

        for (int requestNumber = 1; requestNumber <= 21; requestNumber++) {
            mockMvc.perform(post("/v1/fact")
                            .header("Authorization", "Bearer " + sessionToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(FactRequestFixture.shortFactRequestWithDefaults()))
                    .andExpect(status().isOk());
        }
    }
}
