package ai.dml.motoguide.factproxy;

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
    private final MotoGuideProperties motoGuideProperties;
    private final DiagnosticsSettings diagnosticsSettings;

    public ElevenLabsSpeechService(
            HttpClient httpClient,
            ObjectMapper objectMapper,
            MotoGuideProperties motoGuideProperties,
            DiagnosticsSettings diagnosticsSettings
    ) {
        this.httpClient = httpClient;
        this.objectMapper = objectMapper;
        this.motoGuideProperties = motoGuideProperties;
        this.diagnosticsSettings = diagnosticsSettings;
    }

    public byte[] generateSpeech(ValidatedSpeechRequest request) {
        if (motoGuideProperties.elevenLabsApiKey() == null || motoGuideProperties.elevenLabsApiKey().isBlank()) {
            throw new UpstreamException("ElevenLabs API key is not configured");
        }
        if (motoGuideProperties.elevenLabsVoiceId() == null || motoGuideProperties.elevenLabsVoiceId().isBlank()) {
            throw new UpstreamException("ElevenLabs voice id is not configured");
        }

        try {
            String body = objectMapper.writeValueAsString(Map.of(
                    "text", request.text(),
                    "model_id", configuredModelId()
            ));

            HttpRequest httpRequest = HttpRequest.newBuilder()
                    .uri(speechUri())
                    .timeout(Duration.ofSeconds(15))
                    .header("xi-api-key", motoGuideProperties.elevenLabsApiKey())
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
                throw new UpstreamException("ElevenLabs returned HTTP " + response.statusCode());
            }
            if (response.body() == null || response.body().length == 0) {
                throw new UpstreamException("ElevenLabs returned empty audio");
            }
            return response.body();
        } catch (UpstreamException ex) {
            log.warn("event=elevenlabs_upstream_error reason={}", ex.getMessage());
            throw ex;
        } catch (Exception ex) {
            log.warn("event=elevenlabs_request_failed reason={}", ex.getClass().getSimpleName());
            throw new UpstreamException("ElevenLabs request failed: " + ex.getMessage());
        }
    }

    private URI speechUri() {
        String voiceId = URLEncoder.encode(motoGuideProperties.elevenLabsVoiceId(), StandardCharsets.UTF_8);
        String outputFormat = URLEncoder.encode(configuredOutputFormat(), StandardCharsets.UTF_8);
        return URI.create(ELEVENLABS_BASE_URL + voiceId + "?output_format=" + outputFormat);
    }

    private String configuredModelId() {
        if (motoGuideProperties.elevenLabsModelId() == null || motoGuideProperties.elevenLabsModelId().isBlank()) {
            return "eleven_multilingual_v2";
        }
        return motoGuideProperties.elevenLabsModelId();
    }

    private String configuredOutputFormat() {
        if (motoGuideProperties.elevenLabsOutputFormat() == null || motoGuideProperties.elevenLabsOutputFormat().isBlank()) {
            return "mp3_44100_128";
        }
        return motoGuideProperties.elevenLabsOutputFormat();
    }
}
