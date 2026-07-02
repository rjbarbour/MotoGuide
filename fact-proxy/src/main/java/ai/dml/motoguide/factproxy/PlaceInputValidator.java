package ai.dml.motoguide.factproxy;

import java.util.Locale;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.LinkedHashSet;
import java.util.regex.Pattern;

public final class PlaceInputValidator {
    private static final int MAX_PLACE_NAME_LENGTH = 96;
    private static final int MAX_COUNTRY_CONTEXT_LENGTH = 64;
    private static final int MAX_CUSTOM_FACT_INSTRUCTIONS_LENGTH = 240;
    private static final int MAX_WORDS = 10;
    private static final int MAX_CUSTOM_FACT_INSTRUCTIONS_WORDS = 36;
    private static final int MAX_FACT_INTEREST_CATEGORIES = 7;

    private static final Pattern PLACE_CHARACTERS = Pattern.compile("^[A-Za-z0-9 .,'’&()\\-]+$");
    private static final Pattern COUNTRY_CHARACTERS = Pattern.compile("^[A-Za-z .,'’()\\-]+$");
    private static final Pattern CUSTOM_FACT_INSTRUCTIONS_CHARACTERS = Pattern.compile("^[A-Za-z0-9 .,'’&()\\-]+$");
    private static final Pattern HAS_LETTER = Pattern.compile(".*[A-Za-z].*");
    private static final Pattern REPEATED_PUNCTUATION = Pattern.compile(".*[.,'’&()\\-]{3,}.*");
    private static final Pattern WORD_SPLIT = Pattern.compile("\\s+");
    private static final Pattern TOKEN_SPLIT = Pattern.compile("[^A-Za-z0-9]+");
    private static final Set<String> FACT_INTEREST_CATEGORIES = Set.of(
            "safetyAdvice",
            "geographyBasics",
            "locationFacts",
            "pointsOfInterest",
            "history",
            "culture",
            "landmarks"
    );

    private static final Set<String> INSTRUCTION_TOKENS = Set.of(
            "assistant",
            "developer",
            "ignore",
            "instruction",
            "instructions",
            "json",
            "output",
            "prompt",
            "return",
            "script",
            "system",
            "tool"
    );

    private PlaceInputValidator() {
    }

    public static String validatePlaceName(String value) {
        return validate(value, "placeName", MAX_PLACE_NAME_LENGTH, PLACE_CHARACTERS);
    }

    public static String validateCountryContext(String value) {
        if (value == null || value.isBlank() || "N/A".equalsIgnoreCase(value.trim())) {
            return null;
        }
        return validate(value, "countryContext", MAX_COUNTRY_CONTEXT_LENGTH, COUNTRY_CHARACTERS);
    }

    public static String validateOptionalPlaceName(String value, String field) {
        if (value == null || value.isBlank() || "N/A".equalsIgnoreCase(value.trim())) {
            return null;
        }
        return validate(value, field, MAX_PLACE_NAME_LENGTH, PLACE_CHARACTERS);
    }

    public static String validateOptionalCountryName(String value, String field) {
        if (value == null || value.isBlank() || "N/A".equalsIgnoreCase(value.trim())) {
            return null;
        }
        return validate(value, field, MAX_COUNTRY_CONTEXT_LENGTH, COUNTRY_CHARACTERS);
    }

    public static List<String> validateFamiliarRegions(List<String> values) {
        if (values == null || values.isEmpty()) {
            return List.of();
        }

        if (values.size() > 12) {
            throw new BadRequestException("riderContext.familiarRegions has too many entries");
        }

        ArrayList<String> normalizedValues = new ArrayList<>();
        for (String value : values) {
            if (value == null || value.isBlank()) {
                continue;
            }

            String normalized = validate(value, "familiarRegions", MAX_PLACE_NAME_LENGTH, PLACE_CHARACTERS);
            if (!normalizedValues.contains(normalized)) {
                normalizedValues.add(normalized);
            }
        }

        return normalizedValues;
    }

    public static String validateCustomFactInstructions(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }

        String normalized = normalizeCommon(value);
        if (normalized.length() > MAX_CUSTOM_FACT_INSTRUCTIONS_LENGTH) {
            throw new BadRequestException("riderContext.customFactInstructions is too long");
        }
        if (!HAS_LETTER.matcher(normalized).matches()) {
            throw new BadRequestException("riderContext.customFactInstructions must contain at least one Latin letter");
        }
        if (!CUSTOM_FACT_INSTRUCTIONS_CHARACTERS.matcher(normalized).matches()) {
            throw new BadRequestException("riderContext.customFactInstructions contains unsupported characters");
        }
        if (WORD_SPLIT.split(normalized).length > MAX_CUSTOM_FACT_INSTRUCTIONS_WORDS) {
            throw new BadRequestException("riderContext.customFactInstructions has too many words");
        }
        if (REPEATED_PUNCTUATION.matcher(normalized).matches()) {
            throw new BadRequestException("riderContext.customFactInstructions contains suspicious punctuation");
        }
        rejectInstructionControlInput(normalized, "riderContext.customFactInstructions");
        return normalized;
    }

    public static List<String> validateFactInterestCategories(List<String> values) {
        if (values == null || values.isEmpty()) {
            return List.of();
        }

        if (values.size() > MAX_FACT_INTEREST_CATEGORIES) {
            throw new BadRequestException("riderContext.factInterestCategories has too many entries");
        }

        LinkedHashSet<String> normalizedCategories = new LinkedHashSet<>();
        for (String value : values) {
            if (value == null || value.isBlank()) {
                continue;
            }
            String normalized = normalizeCommon(value);
            if (!FACT_INTEREST_CATEGORIES.contains(normalized)) {
                throw new BadRequestException("riderContext.factInterestCategories contains unknown value");
            }
            normalizedCategories.add(normalized);
        }

        return List.copyOf(normalizedCategories);
    }

    private static String validate(String value, String field, int maxLength, Pattern allowedCharacters) {
        if (value == null || value.isBlank()) {
            throw new BadRequestException(field + " is required");
        }

        String normalized = normalizeCommon(value);
        if (normalized.length() > maxLength) {
            throw new BadRequestException(field + " is too long");
        }
        if (!HAS_LETTER.matcher(normalized).matches()) {
            throw new BadRequestException(field + " must contain at least one Latin letter");
        }
        if (!allowedCharacters.matcher(normalized).matches()) {
            throw new BadRequestException(field + " contains unsupported characters");
        }
        if (WORD_SPLIT.split(normalized).length > MAX_WORDS) {
            throw new BadRequestException(field + " has too many words");
        }
        if (REPEATED_PUNCTUATION.matcher(normalized).matches()) {
            throw new BadRequestException(field + " contains suspicious punctuation");
        }
        rejectInstructionLikeInput(normalized, field);
        return normalized;
    }

    private static String normalizeCommon(String value) {
        return value.trim().replaceAll("\\s+", " ");
    }

    private static void rejectInstructionLikeInput(String value, String field) {
        for (String token : TOKEN_SPLIT.split(value.toLowerCase(Locale.ROOT))) {
            if (INSTRUCTION_TOKENS.contains(token)) {
                throw new BadRequestException(field + " does not look like a place name");
            }
        }
    }

    private static void rejectInstructionControlInput(String value, String field) {
        Set<String> blockedTokens = Set.of(
                "assistant",
                "developer",
                "ignore",
                "json",
                "output",
                "return",
                "script",
                "system",
                "tool"
        );
        for (String token : TOKEN_SPLIT.split(value.toLowerCase(Locale.ROOT))) {
            if (blockedTokens.contains(token)) {
                throw new BadRequestException(field + " contains unsafe instruction language");
            }
        }
    }
}
