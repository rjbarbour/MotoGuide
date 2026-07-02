package ai.dml.motoguide.factproxy;

import org.springframework.boot.context.properties.ConfigurationProperties;

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
        String promptOverridesAuthToken
) {
}
