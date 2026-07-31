package ai.digitalmercenaries.ridehorizon.factproxy;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;

@ConfigurationProperties(prefix = "ridehorizon")
public record RideHorizonProperties(
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
        String promptOverridesHostAllowlist,
        String elevenLabsApiKey,
        String elevenLabsVoiceId,
        String elevenLabsModelId,
        String elevenLabsOutputFormat,
        long attestationChallengeTtlSeconds,
        long sessionTtlSeconds,
        long fallbackSessionTtlSeconds,
        int verifiedFactDailyLimit,
        int verifiedSpeechCharDailyLimit,
        int fallbackFactDailyLimit,
        int fallbackSpeechCharDailyLimit,
        int globalFactDailyLimit,
        int globalSpeechCharDailyLimit,
        long sessionRecordRetentionDays,
        long challengeRecordRetentionHours,
        long fallbackUsageRetentionDays,
        long retentionCleanupInitialDelayMs,
        long retentionCleanupDelayMs
) {
    public static final int DEFAULT_VERIFIED_FACT_DAILY_LIMIT = 180;
    public static final int DEFAULT_VERIFIED_SPEECH_CHAR_DAILY_LIMIT = 120_000;
    public static final int DEFAULT_FALLBACK_FACT_DAILY_LIMIT = 20;
    public static final int DEFAULT_FALLBACK_SPEECH_CHAR_DAILY_LIMIT = 12_000;
    public static final int DEFAULT_GLOBAL_FACT_DAILY_LIMIT = 2_000;
    public static final int DEFAULT_GLOBAL_SPEECH_CHAR_DAILY_LIMIT = 250_000;

    public long safeSessionRecordRetentionDays() {
        return Math.max(sessionRecordRetentionDays, 1);
    }

    public long safeChallengeRecordRetentionHours() {
        return Math.max(challengeRecordRetentionHours, 1);
    }

    public long safeFallbackUsageRetentionDays() {
        return Math.max(fallbackUsageRetentionDays, 1);
    }

    public int safeVerifiedFactDailyLimit() {
        return Math.max(verifiedFactDailyLimit, 1);
    }

    public int safeVerifiedSpeechCharDailyLimit() {
        return Math.max(verifiedSpeechCharDailyLimit, 100);
    }

    public int safeFallbackFactDailyLimit() {
        return Math.max(fallbackFactDailyLimit, 1);
    }

    public int safeFallbackSpeechCharDailyLimit() {
        return Math.max(fallbackSpeechCharDailyLimit, 1);
    }

    public int safeGlobalFactDailyLimit() {
        return Math.max(globalFactDailyLimit, 1);
    }

    public int safeGlobalSpeechCharDailyLimit() {
        return Math.max(globalSpeechCharDailyLimit, 100);
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
                .map(entry -> entry.toLowerCase(Locale.ROOT))
                .forEach(values::add);
        return values;
    }
}
