package ai.digitalmercenaries.ridehorizon.factproxy;

import java.util.Arrays;
import java.util.stream.Collectors;

public enum FactMode {
    SHORT_FACTS(
            "shortFacts",
            1100,
            2,
            "Write 35 to 45 words of ride-relevant local context, usually one sentence and never more than two. "
                    + "Give it a practical place-awareness angle for riders passing through. "
                    + "Prioritise geography, landmarks, and local distinctiveness over generic definitions. "
                    + "Keep practical or safety advice brief and only when truly relevant."
    ),
    LONG_FACTS(
            "longFacts",
            1500,
            4,
            "Write 75 to 90 words of local context with geography, cultural character, and practical significance. "
                    + "Prioritise what is distinctive about this place and why it matters to a rider nearby. "
                    + "Keep practical or safety framing brief and only when truly relevant."
    );

    private final String wireValue;
    private final int maxFactLength;
    private final int maxSentences;
    private final String defaultPrompt;

    FactMode(
            String wireValue,
            int maxFactLength,
            int maxSentences,
            String defaultPrompt
    ) {
        this.wireValue = wireValue;
        this.maxFactLength = maxFactLength;
        this.maxSentences = maxSentences;
        this.defaultPrompt = defaultPrompt;
    }

    public String wireValue() {
        return wireValue;
    }

    public int maxFactLength() {
        return maxFactLength;
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
