package ai.digitalmercenaries.ridehorizon.factproxy;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.Locale;
import java.util.Set;

enum ElevenLabsFailureCode {
    AUTHENTICATION("RH-TTS-01"),
    ACCOUNT_CAPACITY("RH-TTS-02"),
    THROTTLED("RH-TTS-03"),
    UPSTREAM_FAILURE("RH-TTS-04");

    private static final Set<String> ACCOUNT_CAPACITY_CODES = Set.of(
            "quota_exceeded",
            "credit_quota_exceeded",
            "insufficient_credits",
            "payment_required",
            "subscription_required"
    );

    private final String wireCode;

    ElevenLabsFailureCode(String wireCode) {
        this.wireCode = wireCode;
    }

    String wireCode() {
        return wireCode;
    }

    static ElevenLabsFailureCode classify(int statusCode, byte[] responseBody, ObjectMapper objectMapper) {
        String providerCode = providerCode(responseBody, objectMapper);
        if (ACCOUNT_CAPACITY_CODES.contains(providerCode)) {
            return ACCOUNT_CAPACITY;
        }
        if (statusCode == 402) {
            return ACCOUNT_CAPACITY;
        }
        if (statusCode == 429) {
            return THROTTLED;
        }
        if (statusCode == 401 || statusCode == 403) {
            return AUTHENTICATION;
        }
        return UPSTREAM_FAILURE;
    }

    private static String providerCode(byte[] responseBody, ObjectMapper objectMapper) {
        if (responseBody == null || responseBody.length == 0) {
            return "";
        }

        try {
            JsonNode root = objectMapper.readTree(responseBody);
            JsonNode detail = root.path("detail");
            String value = firstText(
                    detail.path("code"),
                    detail.path("status"),
                    detail.path("type"),
                    root.path("code"),
                    root.path("status"),
                    root.path("type")
            );
            return value.toLowerCase(Locale.ROOT);
        } catch (Exception ignored) {
            return "";
        }
    }

    private static String firstText(JsonNode... candidates) {
        for (JsonNode candidate : candidates) {
            if (candidate.isTextual() && !candidate.asText().isBlank()) {
                return candidate.asText().trim();
            }
        }
        return "";
    }
}
