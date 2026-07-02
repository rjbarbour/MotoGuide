package ai.dml.motoguide.factproxy;

import java.util.Arrays;
import java.util.stream.Collectors;

public enum FactMode {
    SHORT_FACTS(
            "shortFacts",
            900,
            560,
            5,
            "Give up to five concise, practical facts focused on why this place is worth noticing while riding. "
                    + "Prioritise local history, distinctive geography, or practical observations. "
                    + "Skip basic administrative definitions unless they are genuinely useful context."
    ),
    LONG_FACTS(
            "longFacts",
            1100,
            760,
            7,
            "Give up to seven concise local-context sentences with history, geography, or practical rider relevance. "
                    + "Prioritise what is distinctive about this place, especially facts that are useful to a rider passing through or near it."
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
