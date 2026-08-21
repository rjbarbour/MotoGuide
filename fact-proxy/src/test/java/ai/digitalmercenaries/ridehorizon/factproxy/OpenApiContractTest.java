package ai.digitalmercenaries.ridehorizon.factproxy;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.parser.OpenAPIV3Parser;
import io.swagger.v3.parser.core.models.ParseOptions;
import io.swagger.v3.parser.core.models.SwaggerParseResult;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertTrue;

final class OpenApiContractTest {
    private static final String ACCEPTED_OPENAPI_VERSION = "3.0.3";
    private static final String ACCEPTED_CONTRACT_VERSION = "0.3.0";
    private static final String ACCEPTED_CONTRACT_SHA256 =
            "1925a6222c150935d520e38deff3143b74e926f66e393677b6761f073b1d8e50";

    private static final Map<String, String> PUBLISHED_OPERATIONS = Map.ofEntries(
            Map.entry("GET /health", "getHealth"),
            Map.entry("POST /v1/fact", "createPlaceFact"),
            Map.entry("POST /v1/speech", "createSpeech"),
            Map.entry("POST /v1/session/fallback", "issueFallbackSession"),
            Map.entry("GET /admin/v1/sessions", "listInstallations"),
            Map.entry("DELETE /admin/v1/sessions/{installationId}", "revokeInstallation"),
            Map.entry("GET /admin/diagnostics", "getDiagnostics"),
            Map.entry("PUT /admin/diagnostics", "updateDiagnostics")
    );

    private static final Set<String> PUBLISHED_SCHEMAS = Set.of(
            "Boundary",
            "DiagnosticsRequest",
            "DiagnosticsResponse",
            "FactRequest",
            "FactResponse",
            "FallbackSessionRequest",
            "InstallationSummary",
            "OptionalCountryName",
            "OptionalPlaceName",
            "PlaceHierarchy",
            "RiderContext",
            "SessionResponse",
            "SpeechErrorResponse",
            "SpeechRequest"
    );

    private static final Set<String> PUBLISHED_SECURITY_SCHEMES = Set.of(
            "RideHorizonAdminToken",
            "RideHorizonProxyToken"
    );

    @Test
    void configuredContractIsValidAndComplete() {
        Path contract = Path.of(System.getProperty("ridehorizon.openapi.contract"));

        List<String> errors = validate(contract);

        assertTrue(errors.isEmpty(), () -> String.join(System.lineSeparator(), errors));
    }

    @Test
    void intentionalVersionDriftFixtureFailsValidation() throws URISyntaxException {
        Path fixture = Path.of(
                OpenApiContractTest.class
                        .getResource("/contracts/openapi/version-drift.yaml")
                        .toURI()
        );

        List<String> errors = validate(fixture);

        assertTrue(
                errors.stream().anyMatch(error -> error.contains("info.version")),
                () -> "Expected version drift failure, got: " + errors
        );
    }

    private static List<String> validate(Path contract) {
        ParseOptions options = new ParseOptions();
        options.setResolve(true);
        options.setResolveFully(true);
        options.setResolveCombinators(true);

        SwaggerParseResult result = new OpenAPIV3Parser().readLocation(
                contract.toAbsolutePath().toString(),
                null,
                options
        );
        List<String> errors = new ArrayList<>();
        if (result.getMessages() != null) {
            result.getMessages().stream()
                    .map(message -> "parser: " + message)
                    .forEach(errors::add);
        }

        OpenAPI openAPI = result.getOpenAPI();
        if (openAPI == null) {
            errors.add("parser: no OpenAPI document was produced");
            return errors;
        }

        requireEqual(errors, "openapi", ACCEPTED_OPENAPI_VERSION, openAPI.getOpenapi());
        requireEqual(
                errors,
                "info.version",
                ACCEPTED_CONTRACT_VERSION,
                openAPI.getInfo() == null ? null : openAPI.getInfo().getVersion()
        );
        requireEqual(errors, "contract SHA-256", ACCEPTED_CONTRACT_SHA256, sha256(contract));
        requireEqual(errors, "published operations", PUBLISHED_OPERATIONS, operations(openAPI));
        requireEqual(
                errors,
                "published schemas",
                PUBLISHED_SCHEMAS,
                openAPI.getComponents() == null || openAPI.getComponents().getSchemas() == null
                        ? Set.of()
                        : new LinkedHashSet<>(openAPI.getComponents().getSchemas().keySet())
        );
        requireEqual(
                errors,
                "published security schemes",
                PUBLISHED_SECURITY_SCHEMES,
                openAPI.getComponents() == null || openAPI.getComponents().getSecuritySchemes() == null
                        ? Set.of()
                        : new LinkedHashSet<>(openAPI.getComponents().getSecuritySchemes().keySet())
        );
        return errors;
    }

    private static Map<String, String> operations(OpenAPI openAPI) {
        Map<String, String> operations = new LinkedHashMap<>();
        if (openAPI.getPaths() == null) {
            return operations;
        }
        openAPI.getPaths().forEach((path, item) ->
                item.readOperationsMap().forEach((method, operation) ->
                        operations.put(method.name() + " " + path, operationId(operation))
                )
        );
        return operations;
    }

    private static String operationId(Operation operation) {
        return operation == null ? null : operation.getOperationId();
    }

    private static String sha256(Path contract) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(Files.readAllBytes(contract));
            return java.util.HexFormat.of().formatHex(digest);
        } catch (IOException | NoSuchAlgorithmException error) {
            return "unavailable: " + error.getMessage();
        }
    }

    private static void requireEqual(
            List<String> errors,
            String field,
            Object expected,
            Object actual
    ) {
        if (!expected.equals(actual)) {
            errors.add(field + " drifted; expected=" + expected + ", actual=" + actual);
        }
    }
}
