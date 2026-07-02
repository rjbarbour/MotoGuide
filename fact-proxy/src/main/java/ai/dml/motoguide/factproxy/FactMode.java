package ai.dml.motoguide.factproxy;

import java.util.Arrays;
import java.util.stream.Collectors;

public enum FactMode {
    SHORT_FACTS("shortFacts", 120, 60),
    LONG_FACTS("longFacts", 280, 140);

    private final String wireValue;
    private final int maxFactLength;
    private final int maxCompletionTokens;

    FactMode(String wireValue, int maxFactLength, int maxCompletionTokens) {
        this.wireValue = wireValue;
        this.maxFactLength = maxFactLength;
        this.maxCompletionTokens = maxCompletionTokens;
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
