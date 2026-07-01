package ai.dml.motoguide.factproxy;

public final class FactSanitizer {
    public static final int MAX_FACT_LENGTH = 120;

    private FactSanitizer() {
    }

    public static String sanitize(String fact) {
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

        if (text.length() > MAX_FACT_LENGTH) {
            text = text.substring(0, MAX_FACT_LENGTH).trim();
        }

        return text.isEmpty() ? null : text;
    }
}
