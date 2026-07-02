package ai.dml.motoguide.factproxy;

import java.util.Arrays;
import java.util.Locale;
import java.util.regex.Pattern;

public final class FactSanitizer {
    public static final int MAX_SHORT_FACT_LENGTH = FactMode.SHORT_FACTS.maxFactLength();
    public static final int MAX_LONG_FACT_LENGTH = FactMode.LONG_FACTS.maxFactLength();

    private static final Pattern WORD_CHARS = Pattern.compile("[a-z]", Pattern.CASE_INSENSITIVE);
    private static final Pattern SENTENCE_BOUNDARY = Pattern.compile("(?<=[.!?])\\s+");
    private static final String[] FORBIDDEN_PHRASES = {
            "you should",
            "you must",
            "please",
            "visit",
            "go to",
            "head to",
            "take a look",
            "check out",
            "follow the",
            "take the",
            "turn left",
            "turn right",
            "speed up",
            "speed down",
            "slow down",
            "keep to"
    };
    private static final Pattern[] FORBIDDEN_PATTERNS;

    static {
        FORBIDDEN_PATTERNS = Arrays.stream(FORBIDDEN_PHRASES)
                .map(phrase -> Pattern.compile("(?i)\\b" + Pattern.quote(phrase) + "\\b"))
                .toArray(Pattern[]::new);
    }

    private FactSanitizer() {
    }

    public static String sanitize(String fact) {
        return sanitize(fact, FactMode.SHORT_FACTS);
    }

    public static String sanitize(String fact, FactMode mode) {
        if (fact == null) {
            return null;
        }

        String text = sanitizeText(fact);
        if (text == null) {
            return null;
        }

        if (containsQuestionOrUnsafeLanguage(text)) {
            return null;
        }

        if (!containsAlphabeticWord(text)) {
            return null;
        }

        if (exceedsSentenceLimit(text, mode)) {
            return null;
        }

        text = trimToLength(text, mode.maxFactLength());
        if (text == null || text.isEmpty()) {
            return null;
        }

        return text;
    }

    private static String sanitizeText(String raw) {
        String text = raw.trim();
        if (text.isEmpty()) {
            return null;
        }
        if ((text.startsWith("\"") && text.endsWith("\"")) || (text.startsWith("'") && text.endsWith("'"))) {
            text = text.substring(1, text.length() - 1).trim();
        }
        text = text.replace('\n', ' ').trim();
        return text.isEmpty() ? null : text;
    }

    private static boolean containsQuestionOrUnsafeLanguage(String text) {
        String lowered = text.toLowerCase(Locale.ROOT);
        return text.contains("?") || containsForbiddenLanguage(lowered);
    }

    private static boolean containsForbiddenLanguage(String normalized) {
        return Arrays.stream(FORBIDDEN_PATTERNS)
                .anyMatch(pattern -> pattern.matcher(normalized).find());
    }

    private static boolean containsAlphabeticWord(String normalized) {
        return WORD_CHARS.matcher(normalized).find();
    }

    private static boolean exceedsSentenceLimit(String text, FactMode mode) {
        return countSentences(text) > mode.maxSentences();
    }

    private static String trimToLength(String text, int maxFactLength) {
        if (text.length() <= maxFactLength) {
            return text;
        }
        String truncated = text.substring(0, maxFactLength).trim();
        return truncated.isEmpty() ? null : truncated;
    }

    private static int countSentences(String value) {
        String trimmed = value.trim();
        if (trimmed.isEmpty()) {
            return 0;
        }
        String[] chunks = SENTENCE_BOUNDARY.split(trimmed);
        return chunks.length;
    }
}
