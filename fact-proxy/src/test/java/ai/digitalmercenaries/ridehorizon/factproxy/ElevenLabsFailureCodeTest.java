package ai.digitalmercenaries.ridehorizon.factproxy;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ElevenLabsFailureCodeTest {
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void classifiesLegacyQuotaResponseAsAccountCapacity() {
        byte[] body = """
                {"detail":{"status":"quota_exceeded","message":"Sensitive provider account wording"}}
                """.getBytes(StandardCharsets.UTF_8);

        assertEquals(
                ElevenLabsFailureCode.ACCOUNT_CAPACITY,
                ElevenLabsFailureCode.classify(401, body, objectMapper)
        );
    }

    @Test
    void classifiesPaymentRequiredAsAccountCapacity() {
        assertEquals(
                ElevenLabsFailureCode.ACCOUNT_CAPACITY,
                ElevenLabsFailureCode.classify(402, new byte[0], objectMapper)
        );
    }

    @Test
    void classifiesAuthenticationFailure() {
        byte[] body = """
                {"detail":{"code":"invalid_api_key"}}
                """.getBytes(StandardCharsets.UTF_8);

        assertEquals(
                ElevenLabsFailureCode.AUTHENTICATION,
                ElevenLabsFailureCode.classify(401, body, objectMapper)
        );
    }

    @Test
    void classifiesThrottlingAndGenericFailures() {
        assertEquals(
                ElevenLabsFailureCode.THROTTLED,
                ElevenLabsFailureCode.classify(429, new byte[0], objectMapper)
        );
        assertEquals(
                ElevenLabsFailureCode.UPSTREAM_FAILURE,
                ElevenLabsFailureCode.classify(500, new byte[0], objectMapper)
        );
    }
}
