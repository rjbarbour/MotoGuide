package ai.dml.motoguide.factproxy;

public final class FactSanitizer {
    public static final int MAX_SHORT_FACT_LENGTH = FactMode.SHORT_FACTS.maxFactLength();
    public static final int MAX_LONG_FACT_LENGTH = FactMode.LONG_FACTS.maxFactLength();

    private FactSanitizer() {
    }

    public static String sanitize(String fact) {
        return sanitize(fact, FactMode.SHORT_FACTS);
    }

    public static String sanitize(String fact, FactMode mode) {
        if (fact == null) {
            return null;
        }

        String text = fact.trim();
        if (text.isEmpty()) {
            return null;
        }

        if ((text.startsWith("\"") && text.endsWith("\""))
                || (text.startsWith("'") && text.endsWith("'"))) {
            text = text.substring(1, text.length() - 1).trim();
        }

        text = text.replace('\n', ' ').trim();

        if (text.contains("?") || text.toLowerCase().contains("you should")) {
            return null;
        }

        int maxFactLength = mode.maxFactLength();
        if (text.length() > maxFactLength) {
            text = text.substring(0, maxFactLength).trim();
        }

        return text.isEmpty() ? null : text;
    }
}
