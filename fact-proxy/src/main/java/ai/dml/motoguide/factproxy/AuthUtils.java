package ai.dml.motoguide.factproxy;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

final class AuthUtils {
    private static final String AUTHORIZATION_PREFIX = "Bearer ";

    private AuthUtils() {
    }

    static String parseBearerToken(String authorization) {
        if (authorization == null) {
            return null;
        }

        String trimmed = authorization.trim();
        if (trimmed.length() < AUTHORIZATION_PREFIX.length()
                || !trimmed.regionMatches(true, 0, AUTHORIZATION_PREFIX, 0, AUTHORIZATION_PREFIX.length())) {
            return null;
        }

        return trimmed.substring(AUTHORIZATION_PREFIX.length()).trim();
    }

    static boolean tokenEquals(String expected, String actual) {
        if (expected == null || actual == null) {
            return false;
        }
        byte[] expectedBytes = expected.getBytes(StandardCharsets.UTF_8);
        byte[] actualBytes = actual.getBytes(StandardCharsets.UTF_8);
        return MessageDigest.isEqual(expectedBytes, actualBytes);
    }

}
