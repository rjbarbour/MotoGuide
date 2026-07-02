package ai.dml.motoguide.factproxy;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "motoguide.proxy-token=test-token",
        "motoguide.device-binding-required=true",
        "motoguide.trusted-device-ids=helmet-a,helmet-b",
        "openai.api-key=test-key"
})
class DeviceBindingProxyAuthTest {

    @Autowired
    private MockMvc mockMvc;

    @org.springframework.boot.test.mock.mockito.MockBean
    private OpenAiService openAiService;

    @Test
    void factIsRejectedWithoutDeviceIdWhenBindingEnabled() throws Exception {
        when(openAiService.generateFact(any())).thenReturn("Known for its wool trade.");

        mockMvc.perform(post("/v1/fact")
                        .header("Authorization", "Bearer test-token")
                        .contentType("application/json")
                        .content(FactRequestFixture.shortFactRequestWithDefaults()))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void factIsRejectedWithUntrustedDeviceIdWhenBindingEnabled() throws Exception {
        when(openAiService.generateFact(any())).thenReturn("Known for its wool trade.");

        mockMvc.perform(post("/v1/fact")
                        .header("Authorization", "Bearer test-token")
                        .header("X-MotoGuide-Device-Id", "unknown-device")
                        .contentType("application/json")
                        .content(FactRequestFixture.shortFactRequestWithDefaults()))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void factIsAcceptedWithTrustedDeviceIdWhenBindingEnabled() throws Exception {
        when(openAiService.generateFact(any())).thenReturn("Known for its wool trade.");

        mockMvc.perform(post("/v1/fact")
                        .header("Authorization", "Bearer test-token")
                        .header("X-MotoGuide-Device-Id", "helmet-a")
                        .contentType("application/json")
                        .content(FactRequestFixture.shortFactRequestWithDefaults()))
                .andExpect(status().isOk());
    }
}
