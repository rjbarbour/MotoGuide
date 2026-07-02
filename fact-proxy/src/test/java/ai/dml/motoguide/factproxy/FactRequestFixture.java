package ai.dml.motoguide.factproxy;

public final class FactRequestFixture {
    private static final String DEFAULT_HIERARCHY_JSON = """
            {"town":"Stroud","county":"Gloucestershire","region":"England","country":"United Kingdom"}
            """;

    private FactRequestFixture() {
    }

    public static String shortFactRequestWithDefaults() {
        return factRequest("town", "Stroud", "shortFacts", "United Kingdom", DEFAULT_HIERARCHY_JSON, null);
    }

    public static String longFactRequestWithDefaults() {
        return factRequest("town", "Stroud", "longFacts", "United Kingdom", DEFAULT_HIERARCHY_JSON, null);
    }

    public static String townWithOnlyRequiredFields(String factMode) {
        return factRequest("town", "Stroud", factMode, null, "{\"town\":\"Stroud\"}", null);
    }

    public static String withUnknownTopLevelField() {
        return factRequest(
                "town",
                "Stroud",
                "shortFacts",
                null,
                "{\"town\":\"Stroud\"}",
                """
                        ,"mysteryField":"unexpected"
                        """
        );
    }

    public static String withUnknownNestedHierarchyField() {
        return factRequest(
                "town",
                "Stroud",
                "shortFacts",
                null,
                """
                        {"town":"Stroud","unexpectedNested":"value"}
                        """,
                null
        );
    }

    public static String missingHierarchy(String factMode) {
        return String.format("""
                {"boundary":"town","placeName":"Stroud","factMode":"%s"}
                """, factMode);
    }

    public static String withPlaceName(String placeName, String factMode) {
        return factRequest("town", placeName, factMode, "United Kingdom", DEFAULT_HIERARCHY_JSON, null);
    }

    public static String factRequest(
            String boundary,
            String placeName,
            String factMode,
            String countryContext,
            String hierarchyJson,
            String extraTopLevel
    ) {
        StringBuilder builder = new StringBuilder();
        builder.append("{");
        builder.append("\"boundary\":\"").append(boundary).append("\",");
        builder.append("\"placeName\":\"").append(placeName).append("\",");
        builder.append("\"factMode\":\"").append(factMode).append("\"");
        if (countryContext != null) {
            builder.append(",\"countryContext\":\"").append(countryContext).append("\"");
        }
        if (hierarchyJson != null) {
            builder.append(",\"placeHierarchy\":").append(hierarchyJson);
        }
        if (extraTopLevel != null && !extraTopLevel.isBlank()) {
            builder.append(extraTopLevel);
        }
        builder.append("}");
        return builder.toString();
    }
}
