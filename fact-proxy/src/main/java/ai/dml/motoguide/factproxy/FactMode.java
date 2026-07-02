package ai.dml.motoguide.factproxy;

import java.util.Arrays;
import java.util.stream.Collectors;

public enum FactMode {
    SHORT_FACTS("shortFacts", 120, 60, 1, "one factual sentence, max 120 characters."),
    LONG_FACTS("longFacts", 280, 140, 2, "one or two short sentences, max 280 characters total.");

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
