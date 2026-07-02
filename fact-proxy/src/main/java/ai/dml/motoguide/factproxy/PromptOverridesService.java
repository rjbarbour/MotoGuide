package ai.dml.motoguide.factproxy;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

@Service
public class PromptOverridesService {
    private static final Logger log = LoggerFactory.getLogger(PromptOverridesService.class);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(4);
    private static final String AUTHORIZATION_HEADER = "Authorization";
    private static final String AUTHORIZATION_PREFIX = "Bearer ";
    private static final Pattern WHITESPACE = Pattern.compile("\\s+");

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final MotoGuideProperties properties;

    private volatile PromptOverridesSnapshot snapshot = PromptOverridesSnapshot.empty();
    private final Object refreshLock = new Object();

    public PromptOverridesService(HttpClient httpClient, ObjectMapper objectMapper, MotoGuideProperties properties) {
        this.httpClient = httpClient;
        this.objectMapper = objectMapper;
        this.properties = properties;
    }

    public String resolvePromptOverride(
            FactMode factMode,
            String userId,
            String boundary,
            ValidatedPlaceHierarchy placeHierarchy
    ) {
        if (!properties.promptOverridesEnabled()) {
            return null;
        }

        PromptOverridesSnapshot current = snapshot();
        if (current.overrides() == null) {
            return null;
        }

        String normalizedUserId = normalizeUserId(userId);
        String userPrompt = promptForUser(current.overrides().userPrompts(), normalizedUserId, factMode);
        if (userPrompt != null) {
            return userPrompt;
        }

        String hierarchyPrompt = promptForHierarchy(current.overrides().hierarchyPrompts(), boundary, placeHierarchy, factMode);
        if (hierarchyPrompt != null) {
            return hierarchyPrompt;
        }

        String boundaryPrompt = promptForBoundary(current.overrides().boundaryPrompts(), boundary, factMode);
        if (boundaryPrompt != null) {
            return boundaryPrompt;
        }

        return current.overrides().modePrompts().get(factMode);
    }

    private String promptForUser(Map<String, Map<FactMode, String>> promptsByUser, String userId, FactMode factMode) {
        if (userId == null || userId.isBlank()) {
            return null;
        }
        Map<FactMode, String> userModePrompts = promptsByUser.get(userId);
        if (userModePrompts == null) {
            return null;
        }

        String prompt = userModePrompts.get(factMode);
        if (prompt != null) {
            return prompt;
        }

        return null;
    }

    private String promptForBoundary(Map<String, Map<FactMode, String>> promptsByBoundary, String boundary, FactMode factMode) {
        if (boundary == null) {
            return null;
        }
        String normalizedBoundary = normalizeLookupPart(boundary);
        if (normalizedBoundary == null) {
            return null;
        }

        Map<FactMode, String> boundaryModePrompts = promptsByBoundary.get(normalizedBoundary);
        if (boundaryModePrompts == null) {
            return null;
        }
        return boundaryModePrompts.get(factMode);
    }

    private String promptForHierarchy(
            Map<String, Map<FactMode, String>> promptsByHierarchy,
            String boundary,
            ValidatedPlaceHierarchy placeHierarchy,
            FactMode factMode
    ) {
        String hierarchyKey = hierarchyLookupKey(boundary, placeHierarchy);
        if (hierarchyKey == null) {
            return null;
        }
        Map<FactMode, String> modePrompts = promptsByHierarchy.get(hierarchyKey);
        if (modePrompts == null) {
            return null;
        }
        return modePrompts.get(factMode);
    }

    private PromptOverridesSnapshot snapshot() {
        PromptOverridesSnapshot current = this.snapshot;
        if (!current.shouldRefreshNow()) {
            return current;
        }

        synchronized (refreshLock) {
            current = this.snapshot;
            if (!current.shouldRefreshNow()) {
                return current;
            }
            PromptOverridesSnapshot loaded = loadFromObjectStore(current);
            this.snapshot = loaded;
            return loaded;
        }
    }

    private PromptOverridesSnapshot loadFromObjectStore(PromptOverridesSnapshot previous) {
        String objectUrl = properties.promptOverridesObjectUrl();
        if (objectUrl == null || objectUrl.isBlank()) {
            log.warn("event=prompt_overrides_load_skipped reason=missing_object_url");
            return new PromptOverridesSnapshot(
                    previous.overrides(),
                    Instant.now().plus(refreshInterval())
            );
        }

        try {
            PromptOverrides promptOverrides = fetchPromptOverrides(objectUrl);
            log.info("event=prompt_overrides_loaded url=prompt-overrides-json");
            return new PromptOverridesSnapshot(promptOverrides, Instant.now().plus(refreshInterval()));
        } catch (Exception ex) {
            log.warn("event=prompt_overrides_load_failed reason={}", ex.getMessage());
            return new PromptOverridesSnapshot(previous.overrides(), Instant.now().plus(refreshInterval()));
        }
    }

    private PromptOverrides fetchPromptOverrides(String objectUrl) throws IOException, InterruptedException {
        URI promptOverridesUri = parsePromptOverridesUriWithAllowlist(objectUrl);
        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder()
                .uri(promptOverridesUri)
                .timeout(REQUEST_TIMEOUT)
                .GET();

        String authToken = properties.promptOverridesAuthToken();
        if (authToken != null && !authToken.isBlank()) {
            requestBuilder.header(AUTHORIZATION_HEADER, AUTHORIZATION_PREFIX + authToken.trim());
        }

        HttpResponse<String> response = httpClient.send(
                requestBuilder.build(),
                HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8)
        );

        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IOException("prompt override store returned HTTP " + response.statusCode());
        }

        return parsePromptOverrides(response.body());
    }

    private static URI parsePromptOverridesUri(String objectUrl) {
        URI uri = URI.create(objectUrl);
        String scheme = uri.getScheme();
        if (scheme == null) {
            throw new IllegalArgumentException("prompt override object url is missing a scheme");
        }
        if (!"https".equalsIgnoreCase(scheme) && !"http".equalsIgnoreCase(scheme)) {
            throw new IllegalArgumentException("prompt override object url must use http or https");
        }
        return uri;
    }

    private URI parsePromptOverridesUriWithAllowlist(String objectUrl) {
        URI uri = parsePromptOverridesUri(objectUrl);
        Set<String> allowedHosts = properties.promptOverridesHostAllowlistSet();
        if (!allowedHosts.isEmpty()) {
            String host = uri.getHost();
            if (host == null || !allowedHosts.contains(host.toLowerCase(Locale.ROOT))) {
                throw new IllegalArgumentException("prompt override object host is not allowlisted");
            }
        }
        return uri;
    }

    private PromptOverrides parsePromptOverrides(String body) throws IOException {
        JsonNode root = objectMapper.readTree(body);
        if (root == null || !root.isObject()) {
            throw new IOException("prompt override body is not a JSON object");
        }

        return new PromptOverrides(
                parseModePrompts(root.get("modePrompts")),
                parsePerSubjectPrompts(root.get("users")),
                parsePerSubjectPrompts(root.get("boundaries")),
                parsePerSubjectPrompts(root.get("hierarchies"))
        );
    }

    private Map<FactMode, String> parseModePrompts(JsonNode node) {
        EnumMap<FactMode, String> prompts = new EnumMap<>(FactMode.class);
        if (node == null || !node.isObject()) {
            return prompts;
        }

        for (FactMode mode : FactMode.values()) {
            JsonNode value = node.get(mode.wireValue());
            if (value != null && value.isTextual()) {
                String normalized = normalizePromptText(value.asText());
                if (!normalized.isBlank()) {
                    prompts.put(mode, normalized);
                }
            }
        }
        return prompts;
    }

    private Map<String, Map<FactMode, String>> parsePerSubjectPrompts(JsonNode node) {
        if (node == null || !node.isObject()) {
            return Map.of();
        }

        Map<String, Map<FactMode, String>> results = new LinkedHashMap<>();
        node.fieldNames().forEachRemaining(subjectKey -> {
            JsonNode subjectNode = node.get(subjectKey);
            if (subjectNode == null || !subjectNode.isObject()) {
                return;
            }
            String normalizedSubjectKey = normalizeLookupKey(subjectKey);
            if (normalizedSubjectKey == null) {
                return;
            }
            Map<FactMode, String> modePrompts = parseModePrompts(subjectNode);
            if (!modePrompts.isEmpty()) {
                results.put(normalizedSubjectKey, modePrompts);
            }
        });

        return results;
    }

    private String normalizePromptText(String value) {
        if (value == null) {
            return "";
        }
        String normalized = WHITESPACE.matcher(value.strip()).replaceAll(" ");
        return normalized;
    }

    private String normalizeUserId(String userId) {
        return UserIdSanitizer.normalizeAndValidate(userId);
    }

    private static String normalizeLookupKey(String value) {
        String normalized = normalizeLookupPart(value);
        if (normalized == null) {
            return null;
        }
        if (normalized.contains(":")) {
            String[] parts = normalized.split(":", 2);
            String first = normalizeLookupPart(parts[0]);
            String second = normalizeLookupPart(parts[1]);
            return first == null || second == null ? null : first + ":" + second;
        }
        return normalized;
    }

    private static String normalizeLookupPart(String value) {
        String normalized = WHITESPACE.matcher(value == null ? "" : value.strip()).replaceAll(" ");
        return normalized.isBlank() ? null : normalized.toLowerCase(Locale.ROOT);
    }

    private String hierarchyLookupKey(String boundary, ValidatedPlaceHierarchy placeHierarchy) {
        if (boundary == null || placeHierarchy == null) {
            return null;
        }
        String lowerBoundary = normalizeLookupPart(boundary);
        if (lowerBoundary == null) {
            return null;
        }
        String locationValue = switch (lowerBoundary) {
            case "country", "nation" -> placeHierarchy.country();
            case "region" -> placeHierarchy.region();
            case "county" -> placeHierarchy.county();
            case "town" -> placeHierarchy.town();
            case "street" -> placeHierarchy.street();
            default -> null;
        };
        String normalizedLocation = normalizeLookupPart(locationValue);
        if (normalizedLocation == null) {
            return null;
        }

        return lowerBoundary + ":" + normalizedLocation;
    }

    private Duration refreshInterval() {
        int refreshSeconds = Math.max(5, properties.promptOverridesRefreshSeconds());
        return Duration.ofSeconds(refreshSeconds);
    }

    private record PromptOverrides(
            Map<FactMode, String> modePrompts,
            Map<String, Map<FactMode, String>> userPrompts,
            Map<String, Map<FactMode, String>> boundaryPrompts,
            Map<String, Map<FactMode, String>> hierarchyPrompts
    ) {
    }

    private record PromptOverridesSnapshot(PromptOverrides overrides, Instant refreshAfter) {
        static PromptOverridesSnapshot empty() {
            return new PromptOverridesSnapshot(new PromptOverrides(
                    Map.of(),
                    Map.of(),
                    Map.of(),
                    Map.of()
            ), Instant.EPOCH);
        }

        boolean shouldRefreshNow() {
            return Instant.now().isAfter(refreshAfter);
        }
    }
}
