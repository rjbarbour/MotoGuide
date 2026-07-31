package ai.digitalmercenaries.ridehorizon.factproxy;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.net.http.HttpClient;

import static org.junit.jupiter.api.Assertions.assertTrue;

class ElevenLabsSpeechServiceTest {
    @Test
    void requestsZeroRetentionProcessing() {
        RideHorizonProperties properties = new RideHorizonProperties(
                "", "", 30, false, "", "", false, "", 60, "", "",
                "test-provider-key", "test-voice", "eleven_multilingual_v2", "mp3_44100_128",
                300, 3600, 900,
                180, 120_000, 20, 12_000, 2_000, 250_000,
                30, 24, 3,
                60000, 21600000
        );
        ElevenLabsSpeechService service = new ElevenLabsSpeechService(
                HttpClient.newHttpClient(),
                new ObjectMapper(),
                properties,
                new DiagnosticsSettings(properties)
        );

        assertTrue(service.speechUri().getQuery().contains("enable_logging=false"));
    }
}
