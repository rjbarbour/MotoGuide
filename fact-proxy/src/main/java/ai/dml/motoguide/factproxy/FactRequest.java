package ai.dml.motoguide.factproxy;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.Set;

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
        if (boundary == null || !ALLOWED_BOUNDARIES.contains(boundary)) {
            throw new BadRequestException("boundary must be one of: country, nation, county, town, street");
        }
        validatedFactMode();
        PlaceInputValidator.validatePlaceName(placeName);
        PlaceInputValidator.validateCountryContext(countryContext);
        if (placeHierarchy == null) {
            throw new BadRequestException("placeHierarchy is required");
        }
        placeHierarchy.validate();
    }

    public String validatedPlaceName() {
        return PlaceInputValidator.validatePlaceName(placeName);
    }

    public String validatedCountryContext() {
        return PlaceInputValidator.validateCountryContext(countryContext);
    }

    public FactMode validatedFactMode() {
        if (factMode == null || factMode.isBlank()) {
            throw new BadRequestException("factMode must be one of: " + FactMode.allowedValues());
        }
        return FactMode.fromWireValue(factMode);
    }
}
