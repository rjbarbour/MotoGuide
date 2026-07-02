package ai.dml.motoguide.factproxy;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.Set;

@JsonIgnoreProperties(ignoreUnknown = false)
public record FactRequest(
        String boundary,
        String placeName,
        String factMode,
        @JsonProperty("countryContext") String countryContext,
        PlaceHierarchy placeHierarchy,
        RiderContext riderContext
) {
    public FactRequest(
            String boundary,
            String placeName,
            String factMode,
            String countryContext,
            PlaceHierarchy placeHierarchy
    ) {
        this(boundary, placeName, factMode, countryContext, placeHierarchy, null);
    }

    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    private static final Set<String> ALLOWED_BOUNDARIES = Set.of(
            "country", "nation", "county", "town", "street"
    );

    public void validate() {
        validateAndNormalize();
    }

    public ValidatedFactRequest validateAndNormalize() {
        return validateAndNormalize(null);
    }

    public ValidatedFactRequest validateAndNormalize(String userId) {
        String normalizedBoundary = boundary() == null ? null : boundary().trim();
        if (normalizedBoundary == null || !ALLOWED_BOUNDARIES.contains(normalizedBoundary)) {
            throw new BadRequestException("boundary must be one of: country, nation, county, town, street");
        }

        FactMode normalizedFactMode = parseFactMode();
        String normalizedPlaceName = PlaceInputValidator.validatePlaceName(placeName);
        String normalizedCountryContext = PlaceInputValidator.validateCountryContext(countryContext);
        if (placeHierarchy == null) {
            throw new BadRequestException("placeHierarchy is required");
        }
        ValidatedPlaceHierarchy validatedPlaceHierarchy = placeHierarchy.validateAndNormalize();
        ValidatedRiderContext validatedRiderContext = riderContext == null
                ? new ValidatedRiderContext(null, null, java.util.List.of(), null, java.util.List.of())
                : riderContext.validateAndNormalize();

        return new ValidatedFactRequest(
                normalizedBoundary,
                normalizedPlaceName,
                normalizedFactMode,
                normalizedCountryContext,
                userId,
                validatedPlaceHierarchy,
                validatedRiderContext
        );
    }

    public String validatedPlaceName() {
        return validateAndNormalize().placeName();
    }

    public String validatedCountryContext() {
        return validateAndNormalize().countryContext();
    }

    public FactMode validatedFactMode() {
        return parseFactMode();
    }

    private FactMode parseFactMode() {
        if (factMode == null || factMode.isBlank()) {
            throw new BadRequestException("factMode must be one of: " + FactMode.allowedValues());
        }
        return FactMode.fromWireValue(factMode);
    }
}

record ValidatedFactRequest(
        String boundary,
        String placeName,
        FactMode factMode,
        String countryContext,
        String userId,
        ValidatedPlaceHierarchy placeHierarchy,
        ValidatedRiderContext riderContext
) {
}

record RiderContext(
        @JsonProperty("homeCountry") String homeCountry,
        @JsonProperty("homeRegion") String homeRegion,
        @JsonProperty("familiarRegions") java.util.List<String> familiarRegions,
        @JsonProperty("customFactInstructions") String customFactInstructions,
        @JsonProperty("factInterestCategories") java.util.List<String> factInterestCategories
) {
    public RiderContext {
        if (familiarRegions == null) {
            familiarRegions = java.util.List.of();
        }
        if (factInterestCategories == null) {
            factInterestCategories = java.util.List.of();
        }
    }

    public RiderContext() {
        this(null, null, java.util.List.of(), null, java.util.List.of());
    }

    public ValidatedRiderContext validateAndNormalize() {
        return new ValidatedRiderContext(
                PlaceInputValidator.validateOptionalCountryName(homeCountry, "riderContext.homeCountry"),
                PlaceInputValidator.validateOptionalPlaceName(homeRegion, "riderContext.homeRegion"),
                PlaceInputValidator.validateFamiliarRegions(familiarRegions),
                PlaceInputValidator.validateCustomFactInstructions(customFactInstructions),
                PlaceInputValidator.validateFactInterestCategories(factInterestCategories)
        );
    }
}

record ValidatedRiderContext(
        String homeCountry,
        String homeRegion,
        java.util.List<String> familiarRegions,
        String customFactInstructions,
        java.util.List<String> factInterestCategories
) {
}
