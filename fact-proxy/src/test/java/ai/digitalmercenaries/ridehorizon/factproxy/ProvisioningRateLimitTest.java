package ai.digitalmercenaries.ridehorizon.factproxy;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "ridehorizon.rate-limit-per-minute=2",
        "spring.datasource.url=jdbc:h2:mem:provision-rate-limit;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.datasource.driver-class-name=org.h2.Driver"
})
class ProvisioningRateLimitTest {
    @Autowired private MockMvc mockMvc;

    @Test
    void changingDeviceHeaderCannotBypassAutomaticSessionIpLimit() throws Exception {
        attempt("device-one").andExpect(status().isOk());
        attempt("device-two").andExpect(status().isOk());
        attempt("device-three").andExpect(status().isTooManyRequests());
    }

    private org.springframework.test.web.servlet.ResultActions attempt(String headerDeviceId) throws Exception {
        return mockMvc.perform(post("/v1/session/fallback")
                .header("X-RideHorizon-Device-Id", headerDeviceId)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"reason\":\"test\"}"));
    }
}
