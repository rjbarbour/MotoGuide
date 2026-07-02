package ai.dml.motoguide.factproxy;

import java.util.Arrays;
import java.util.stream.Collectors;

public enum FactMode {
    SHORT_FACTS(
            "shortFacts",
            1100,
            700,
            5,
            "Give up to five concise, ride-relevant facts that are mostly geographic and cultural, "
                    + "with a practical angle for riders passing through. "
                    + "Prioritise geography, landmarks, and local distinctiveness over generic definitions. "
                    + "Keep practical or safety advice brief and only when truly relevant."
    ),
    LONG_FACTS(
            "longFacts",
            1500,
            1000,
            8,
            "Give up to eight concise local-context sentences with geography, cultural character, and practical significance. "
                    + "Prioritise what is distinctive about this place and why it matters to a rider nearby. "
                    + "Keep practical or safety framing brief and only when truly relevant."
    );

    private final String wireValue;
    private final int maxFactLength;
    private final int maxCompletionTokens;
    private final int maxSentences;
    private final String defaultPrompt;

    FactMode(
            String wireValue,
            int maxFactLength,
            int maxCompletionTokens,
            int maxSentences,
            String defaultPrompt
    ) {
        this.wireValue = wireValue;
        this.maxFactLength = maxFactLength;
        this.maxCompletionTokens = maxCompletionTokens;
        this.maxSentences = maxSentences;
        this.defaultPrompt = defaultPrompt;
    }

    public String wireValue() {
        return wireValue;
    }

    public int maxFactLength() {
        return maxFactLength;
    }

    public int maxCompletionTokens() {
        return maxCompletionTokens;
    }

    public int maxSentences() {
        return maxSentences;
    }

    public String defaultPrompt() {
        return defaultPrompt;
    }

    public static FactMode fromWireValue(String value) {
        for (FactMode mode : values()) {
            if (mode.wireValue.equals(value)) {
                return mode;
            }
        }
        throw new BadRequestException("factMode must be one of: " + allowedValues());
    }

    public static String allowedValues() {
        return Arrays.stream(values())
                .map(FactMode::wireValue)
                .collect(Collectors.joining(", "));
    }
}
