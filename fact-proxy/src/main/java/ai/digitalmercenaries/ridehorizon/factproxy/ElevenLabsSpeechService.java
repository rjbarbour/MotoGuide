package ai.digitalmercenaries.ridehorizon.factproxy;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Map;

@Service
public class ElevenLabsSpeechService {
    private static final Logger log = LoggerFactory.getLogger(ElevenLabsSpeechService.class);
    private static final String ELEVENLABS_BASE_URL = "https://api.elevenlabs.io/v1/text-to-speech/";

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final RideHorizonProperties rideHorizonProperties;
    private final DiagnosticsSettings diagnosticsSettings;

    public ElevenLabsSpeechService(
            HttpClient httpClient,
            ObjectMapper objectMapper,
            RideHorizonProperties rideHorizonProperties,
            DiagnosticsSettings diagnosticsSettings
    ) {
        this.httpClient = httpClient;
        this.objectMapper = objectMapper;
        this.rideHorizonProperties = rideHorizonProperties;
        this.diagnosticsSettings = diagnosticsSettings;
    }

    public byte[] generateSpeech(ValidatedSpeechRequest request) {
        if (rideHorizonProperties.elevenLabsApiKey() == null || rideHorizonProperties.elevenLabsApiKey().isBlank()) {
            throw new SpeechUpstreamException(ElevenLabsFailureCode.AUTHENTICATION, 0);
        }
        if (rideHorizonProperties.elevenLabsVoiceId() == null || rideHorizonProperties.elevenLabsVoiceId().isBlank()) {
            throw new SpeechUpstreamException(ElevenLabsFailureCode.AUTHENTICATION, 0);
        }

        try {
            String body = objectMapper.writeValueAsString(Map.of(
                    "text", request.text(),
                    "model_id", configuredModelId()
            ));

            HttpRequest httpRequest = HttpRequest.newBuilder()
                    .uri(speechUri())
                    .timeout(Duration.ofSeconds(15))
                    .header("xi-api-key", rideHorizonProperties.elevenLabsApiKey())
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8))
                    .build();

            long started = System.nanoTime();
            HttpResponse<byte[]> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofByteArray());
            long durationMs = (System.nanoTime() - started) / 1_000_000;
            if (diagnosticsSettings.enabled()) {
                log.info(
                        "event=elevenlabs_response status={} durationMs={} audioBytes={}",
                        response.statusCode(),
                        durationMs,
                        response.body() == null ? 0 : response.body().length
                );
            }

            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new SpeechUpstreamException(
                        ElevenLabsFailureCode.classify(response.statusCode(), response.body(), objectMapper),
                        response.statusCode()
                );
            }
            if (response.body() == null || response.body().length == 0) {
                throw new SpeechUpstreamException(ElevenLabsFailureCode.UPSTREAM_FAILURE, response.statusCode());
            }
            return response.body();
        } catch (SpeechUpstreamException ex) {
            log.warn(
                    "event=elevenlabs_upstream_error status={} diagnosticCode={}",
                    ex.upstreamStatus(),
                    ex.diagnosticCode()
            );
            throw ex;
        } catch (Exception ex) {
            log.warn("event=elevenlabs_request_failed reason={}", ex.getClass().getSimpleName());
            throw new SpeechUpstreamException(ElevenLabsFailureCode.UPSTREAM_FAILURE, 0, ex);
        }
    }

    private URI speechUri() {
        String voiceId = URLEncoder.encode(rideHorizonProperties.elevenLabsVoiceId(), StandardCharsets.UTF_8);
        String outputFormat = URLEncoder.encode(configuredOutputFormat(), StandardCharsets.UTF_8);
        return URI.create(ELEVENLABS_BASE_URL + voiceId + "?output_format=" + outputFormat);
    }

    private String configuredModelId() {
        if (rideHorizonProperties.elevenLabsModelId() == null || rideHorizonProperties.elevenLabsModelId().isBlank()) {
            return "eleven_multilingual_v2";
        }
        return rideHorizonProperties.elevenLabsModelId();
    }

    private String configuredOutputFormat() {
        if (rideHorizonProperties.elevenLabsOutputFormat() == null || rideHorizonProperties.elevenLabsOutputFormat().isBlank()) {
            return "mp3_44100_128";
        }
        return rideHorizonProperties.elevenLabsOutputFormat();
    }
}
