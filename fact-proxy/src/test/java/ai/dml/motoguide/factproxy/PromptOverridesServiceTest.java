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

    private static PromptOverridesService serviceWithOverridesEnabled(String objectUrl, int refreshSeconds) {
        MotoGuideProperties properties = new MotoGuideProperties(
                "proxy-token",
                null,
                30,
                false,
                null,
                null,
                true,
                objectUrl,
                refreshSeconds,
                null
        );
        return new PromptOverridesService(
                HttpClient.newHttpClient(),
                OBJECT_MAPPER,
                properties
        );
    }

    private static PromptOverridesService serviceWithOverridesEnabled(String objectUrl, boolean enabled) {
        MotoGuideProperties properties = new MotoGuideProperties(
                "proxy-token",
                null,
                30,
                false,
                null,
                null,
                enabled,
                objectUrl,
                60,
                null
        );
        return new PromptOverridesService(
                HttpClient.newHttpClient(),
                OBJECT_MAPPER,
                properties
        );
    }
}
