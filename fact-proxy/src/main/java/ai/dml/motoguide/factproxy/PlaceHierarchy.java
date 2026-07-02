package ai.dml.motoguide.factproxy;

public record PlaceHierarchy(
        String street,
        String town,
        String county,
        String region,
        String country
) {
    public void validate() {
        PlaceInputValidator.validateOptionalPlaceName(street, "placeHierarchy.street");
        PlaceInputValidator.validateOptionalPlaceName(town, "placeHierarchy.town");
        PlaceInputValidator.validateOptionalPlaceName(county, "placeHierarchy.county");
        PlaceInputValidator.validateOptionalPlaceName(region, "placeHierarchy.region");
        PlaceInputValidator.validateOptionalCountryName(country, "placeHierarchy.country");
    }

    public String normalizedStreet() {
        return PlaceInputValidator.validateOptionalPlaceName(street, "placeHierarchy.street");
    }

    public String normalizedTown() {
        return PlaceInputValidator.validateOptionalPlaceName(town, "placeHierarchy.town");
    }

    public String normalizedCounty() {
        return PlaceInputValidator.validateOptionalPlaceName(county, "placeHierarchy.county");
    }

    public String normalizedRegion() {
        return PlaceInputValidator.validateOptionalPlaceName(region, "placeHierarchy.region");
    }

    public String normalizedCountry() {
        return PlaceInputValidator.validateOptionalCountryName(country, "placeHierarchy.country");
    }
}
