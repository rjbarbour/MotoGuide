package ai.dml.motoguide.factproxy;

import java.util.Locale;
import java.util.regex.Pattern;

final class DeviceIdSanitizer {
    private static final Pattern WHITESPACE = Pattern.compile("\\s+");
    private static final Pattern ALLOWED_DEVICE_ID = Pattern.compile("^[a-z0-9._:-]{4,64}$");

    private DeviceIdSanitizer() {
    }

    static String normalize(String value) {
        if (value == null) {
            return null;
        }

        String normalized = WHITESPACE.matcher(value.trim().toLowerCase(Locale.ROOT)).replaceAll("");
        if (normalized.length() < 4 || normalized.length() > 64) {
            return null;
        }
        if (!ALLOWED_DEVICE_ID.matcher(normalized).matches()) {
            return null;
        }
        return normalized;
    }
}
