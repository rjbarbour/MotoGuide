package ai.dml.motoguide.factproxy;

import java.util.Locale;
import java.util.regex.Pattern;

final class UserIdSanitizer {
    private static final Pattern ALLOWED_USER_ID = Pattern.compile("^[a-z0-9._-]{4,64}$");

    private UserIdSanitizer() {
    }

    static String normalizeAndValidate(String userId) {
        if (userId == null) {
            return null;
        }

        String normalized = userId.trim().toLowerCase(Locale.ROOT).replaceAll("\\s+", " ");
        if (!ALLOWED_USER_ID.matcher(normalized).matches()) {
            return null;
        }
        return normalized;
    }
}
