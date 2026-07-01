package ai.dml.motoguide.factproxy;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "motoguide.proxy-token=test-token",
        "openai.api-key=test-key"
})
class AdminDiagnosticsDisabledTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void diagnosticsEndpointIsHiddenWhenAdminTokenIsUnset() throws Exception {
        mockMvc.perform(get("/admin/diagnostics")
                        .header("Authorization", "Bearer anything"))
                .andExpect(status().isNotFound());
    }
}
