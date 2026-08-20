package ai.digitalmercenaries.ridehorizon.factproxy;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "ridehorizon.proxy-token=test-token",
        "ridehorizon.admin-token=test-admin-token",
        "openai.api-key=test-key"
})
final class SharedContractFixtureTest {
    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private OpenAiService openAiService;

    @MockitoBean
    private ElevenLabsSpeechService elevenLabsSpeechService;

    @Test
    void factRequestAndResponseFixturesMatchProductionHttpCodec() throws Exception {
        when(openAiService.generateFact(any())).thenReturn("Known for its historic wool trade.");
        ArgumentCaptor<ValidatedFactRequest> requestCaptor = ArgumentCaptor.forClass(ValidatedFactRequest.class);

        MvcResult result = mockMvc.perform(post("/v1/fact")
                        .header("Authorization", "Bearer test-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fixtureBytes("fact-request.json")))
                .andExpect(status().isOk())
                .andReturn();

        verify(openAiService).generateFact(requestCaptor.capture());
        ValidatedFactRequest request = requestCaptor.getValue();
        assertEquals("town", request.boundary());
        assertEquals("Stroud", request.placeName());
        assertEquals(FactMode.SHORT_FACTS, request.factMode());
        assertEquals("United Kingdom", request.countryContext());
        assertEquals(fixture("fact-response.json"), objectMapper.readTree(result.getResponse().getContentAsByteArray()));
    }

    @Test
    void speechErrorFixtureMatchesProductionHttpCodecAndExceptionHandler() throws Exception {
        when(elevenLabsSpeechService.generateSpeech(any())).thenThrow(
                new SpeechUpstreamException(ElevenLabsFailureCode.ACCOUNT_CAPACITY, 402)
        );

        MvcResult result = mockMvc.perform(post("/v1/speech")
                        .header("Authorization", "Bearer test-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"text\":\"Known for its wool trade.\"}"))
                .andExpect(status().isBadGateway())
                .andReturn();

        assertEquals(
                fixture("speech-error-response.json"),
                objectMapper.readTree(result.getResponse().getContentAsByteArray())
        );
    }

    private JsonNode fixture(String name) throws IOException {
        return objectMapper.readTree(fixtureBytes(name));
    }

    private byte[] fixtureBytes(String name) throws IOException {
        Path path = Path.of(System.getProperty("ridehorizon.contract.fixtures"), name);
        return Files.readAllBytes(path);
    }
}
