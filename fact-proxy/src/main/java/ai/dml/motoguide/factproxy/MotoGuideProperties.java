package ai.dml.motoguide.factproxy;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;

@ConfigurationProperties(prefix = "motoguide")
public record MotoGuideProperties(
        String proxyToken,
        String adminToken,
        int rateLimitPerMinute,
        boolean diagnosticsEnabled,
        String shortFactPrompt,
        String longFactPrompt,
        boolean promptOverridesEnabled,
        String promptOverridesObjectUrl,
        int promptOverridesRefreshSeconds,
        String promptOverridesAuthToken,
        boolean deviceBindingRequired,
        String trustedDeviceIds,
        String promptOverridesHostAllowlist
) {
    public Set<String> trustedDeviceIdSet() {
        return csvToSet(trustedDeviceIds);
    }

    public Set<String> promptOverridesHostAllowlistSet() {
        return csvToSet(promptOverridesHostAllowlist);
    }

    private static Set<String> csvToSet(String value) {
        if (value == null || value.isBlank()) {
            return Collections.emptySet();
        }
        Set<String> values = new LinkedHashSet<>();
        Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(entry -> !entry.isEmpty())
                .forEach(entry -> values.add(entry.toLowerCase(Locale.ROOT)));
        return values;
    }
}
