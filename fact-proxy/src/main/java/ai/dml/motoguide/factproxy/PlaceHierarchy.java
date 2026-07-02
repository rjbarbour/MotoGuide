package ai.dml.motoguide.factproxy;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = false)
public record PlaceHierarchy(
        String street,
        String town,
        String county,
        String region,
        String country
) {
    public void validate() {
        validateAndNormalize();
    }

    public ValidatedPlaceHierarchy validateAndNormalize() {
        return new ValidatedPlaceHierarchy(
                PlaceInputValidator.validateOptionalPlaceName(street, "placeHierarchy.street"),
                PlaceInputValidator.validateOptionalPlaceName(town, "placeHierarchy.town"),
                PlaceInputValidator.validateOptionalPlaceName(county, "placeHierarchy.county"),
                PlaceInputValidator.validateOptionalPlaceName(region, "placeHierarchy.region"),
                PlaceInputValidator.validateOptionalCountryName(country, "placeHierarchy.country")
        );
    }

    public String normalizedStreet() {
        return validateAndNormalize().street();
    }

    public String normalizedTown() {
        return validateAndNormalize().town();
    }

    public String normalizedCounty() {
        return validateAndNormalize().county();
    }

    public String normalizedRegion() {
        return validateAndNormalize().region();
    }

    public String normalizedCountry() {
        return validateAndNormalize().country();
    }
}

record ValidatedPlaceHierarchy(
        String street,
        String town,
        String county,
        String region,
        String country
) {
}
