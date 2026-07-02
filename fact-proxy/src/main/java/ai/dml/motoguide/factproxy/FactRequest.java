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
        PlaceHierarchy placeHierarchy
) {
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    private static final Set<String> ALLOWED_BOUNDARIES = Set.of(
            "country", "nation", "county", "town", "street"
    );

    public void validate() {
        validateAndNormalize();
    }

    public ValidatedFactRequest validateAndNormalize() {
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

        return new ValidatedFactRequest(
                normalizedBoundary,
                normalizedPlaceName,
                normalizedFactMode,
                normalizedCountryContext,
                validatedPlaceHierarchy
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
        ValidatedPlaceHierarchy placeHierarchy
) {
}
