package ai.dml.motoguide.factproxy;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class PromptOverridesServiceTest {
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    @Test
    void resolvesPromptOverridesByConfiguredPrecedence() throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/prompt-overrides.json", exchange -> {
            String responseBody = """
                    {
                      "modePrompts": {
                        "shortFacts": "Global Short",
                        "longFacts": "Global Long"
                      },
                      "users": {
                        "rider-42": {
                          "shortFacts": "User SHORT"
                        }
                      },
                      "boundaries": {
                        "town": {
                          "shortFacts": "Boundary SHORT"
                        }
                      },
                      "hierarchies": {
                        "town:stourbridge": {
                          "shortFacts": "Hierarchy SHORT"
                        },
                        "country:united kingdom": {
                          "longFacts": "Country LONG"
                        }
                      }
                    }
                    """;
            byte[] response = responseBody.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, response.length);
            try (OutputStream outputStream = exchange.getResponseBody()) {
                outputStream.write(response);
            }
        });
        server.start();

        try {
            String overrideUrl = "http://127.0.0.1:" + server.getAddress().getPort() + "/prompt-overrides.json";
            PromptOverridesService service = serviceWithOverridesEnabled(overrideUrl, 5);

            ValidatedPlaceHierarchy stourbridge = new ValidatedPlaceHierarchy(
                    null,
                    "Stourbridge",
                    "West Midlands",
                    "England",
                    "United Kingdom"
            );
            ValidatedPlaceHierarchy cardiff = new ValidatedPlaceHierarchy(
                    null,
                    "Cardiff",
                    "Cardiff",
                    "Wales",
                    "United Kingdom"
            );
            ValidatedPlaceHierarchy uk = new ValidatedPlaceHierarchy(
                    null,
                    null,
                    null,
                    null,
                    "United Kingdom"
            );

            assertEquals("User SHORT", service.resolvePromptOverride(
                    FactMode.SHORT_FACTS,
                    "rider-42",
                    "town",
                    stourbridge
            ));
            assertEquals("Hierarchy SHORT", service.resolvePromptOverride(
                    FactMode.SHORT_FACTS,
                    "other",
                    "town",
                    stourbridge
            ));
            assertEquals("Boundary SHORT", service.resolvePromptOverride(
                    FactMode.SHORT_FACTS,
                    "other",
                    "town",
                    cardiff
            ));
            assertEquals("Country LONG", service.resolvePromptOverride(
                    FactMode.LONG_FACTS,
                    "other",
                    "country",
                    uk
            ));
            assertEquals("Global Short", service.resolvePromptOverride(
                    FactMode.SHORT_FACTS,
                    null,
                    "county",
                    cardiff
            ));
        } finally {
            server.stop(0);
        }
    }

    @Test
    void doesNotResolveOverridesWhenFeatureDisabled() {
        PromptOverridesService service = serviceWithOverridesEnabled("invalid-url", false);
        assertNull(service.resolvePromptOverride(
                FactMode.SHORT_FACTS,
                "rider-42",
                "town",
                new ValidatedPlaceHierarchy("Road", "Stroud", "Gloucestershire", "England", "United Kingdom")
        ));
    }

    @Test
    void ignoresUnsupportedPromptOverrideScheme() {
        PromptOverridesService service = serviceWithOverridesEnabled(
                "file:///tmp/prompt-overrides.json",
                true,
                "localhost"
        );
        assertNull(service.resolvePromptOverride(
                FactMode.SHORT_FACTS,
                "rider-42",
                "town",
                new ValidatedPlaceHierarchy("Road", "Stroud", "Gloucestershire", "England", "United Kingdom")
        ));
    }

    @Test
    void ignoresPromptOverrideHostNotOnAllowlist() throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/prompt-overrides.json", exchange -> {
            String responseBody = """
                    {
                      "modePrompts": {
                        "shortFacts": "Nope"
                      }
                    }
                    """;
            byte[] response = responseBody.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, response.length);
            try (OutputStream outputStream = exchange.getResponseBody()) {
                outputStream.write(response);
            }
        });
        server.start();

        try {
            String objectUrl = "http://127.0.0.1:" + server.getAddress().getPort() + "/prompt-overrides.json";
            PromptOverridesService service = serviceWithOverridesEnabled(objectUrl, false, "prompts.example");
            assertNull(service.resolvePromptOverride(
                    FactMode.SHORT_FACTS,
                    "rider-42",
                    "town",
                    new ValidatedPlaceHierarchy("Road", "Stroud", "Gloucestershire", "England", "United Kingdom")
            ));
        } finally {
            server.stop(0);
        }
    }

    private static PromptOverridesService serviceWithOverridesEnabled(String objectUrl, int refreshSeconds) {
        return serviceWithOverridesEnabled(objectUrl, true, refreshSeconds, "127.0.0.1");
    }

    private static PromptOverridesService serviceWithOverridesEnabled(String objectUrl, int refreshSeconds, String hostAllowlist) {
        MotoGuideProperties properties = newProperties(
                true,
                objectUrl,
                refreshSeconds,
                hostAllowlist
        );
        return new PromptOverridesService(
                HttpClient.newHttpClient(),
                OBJECT_MAPPER,
                properties
        );
    }

    private static PromptOverridesService serviceWithOverridesEnabled(String objectUrl, boolean enabled) {
        return serviceWithOverridesEnabled(objectUrl, enabled, "127.0.0.1");
    }

    private static PromptOverridesService serviceWithOverridesEnabled(
            String objectUrl,
            boolean enabled,
            String hostAllowlist
    ) {
        return serviceWithOverridesEnabled(objectUrl, enabled, 60, hostAllowlist);
    }

    private static PromptOverridesService serviceWithOverridesEnabled(
            String objectUrl,
            boolean enabled,
            int refreshSeconds,
            String hostAllowlist
    ) {
        MotoGuideProperties properties = newProperties(
                enabled,
                objectUrl,
                refreshSeconds,
                hostAllowlist
        );
        return new PromptOverridesService(
                HttpClient.newHttpClient(),
                OBJECT_MAPPER,
                properties
        );
    }

    private static MotoGuideProperties newProperties(
            boolean enabled,
            String objectUrl,
            int refreshSeconds,
            String hostAllowlist
    ) {
        for (var constructor : MotoGuideProperties.class.getDeclaredConstructors()) {
            if (constructor.getParameterCount() == 13) {
                try {
                    return (MotoGuideProperties) constructor.newInstance(
                            "proxy-token",
                            null,
                            30,
                            false,
                            null,
                            null,
                            enabled,
                            objectUrl,
                            refreshSeconds,
                            null,
                            false,
                            null,
                            hostAllowlist
                    );
                } catch (ReflectiveOperationException ex) {
                    throw new RuntimeException(ex);
                }
            }
            if (constructor.getParameterCount() == 12) {
                try {
                    return (MotoGuideProperties) constructor.newInstance(
                            "proxy-token",
                            null,
                            30,
                            false,
                            null,
                            null,
                            enabled,
                            objectUrl,
                            refreshSeconds,
                            null,
                            false,
                            null
                    );
                } catch (ReflectiveOperationException ex) {
                    throw new RuntimeException(ex);
                }
            }
        }
        throw new IllegalStateException("Unexpected MotoGuideProperties constructor signature");
    }

    @Test
    void failsToLoadOverridesWhenHostAllowlistIsMissing() {
        PromptOverridesService service = serviceWithOverridesEnabled(
                "https://object-store.example.com/prompt-overrides.json",
                false,
                null
        );
        assertNull(service.resolvePromptOverride(
                FactMode.SHORT_FACTS,
                null,
                "town",
                new ValidatedPlaceHierarchy("Road", "Stroud", "Gloucestershire", "England", "United Kingdom")
        ));
    }
}
