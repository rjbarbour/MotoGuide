package ai.dml.motoguide.factproxy;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class FactController {
    private static final Logger log = LoggerFactory.getLogger(FactController.class);
    private static final String USER_HEADER = "X-MotoGuide-User-Id";

    private final OpenAiService openAiService;
    private final ElevenLabsSpeechService elevenLabsSpeechService;
    private final DiagnosticsSettings diagnosticsSettings;

    public FactController(
            OpenAiService openAiService,
            ElevenLabsSpeechService elevenLabsSpeechService,
            DiagnosticsSettings diagnosticsSettings
    ) {
        this.openAiService = openAiService;
        this.elevenLabsSpeechService = elevenLabsSpeechService;
        this.diagnosticsSettings = diagnosticsSettings;
    }

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("ok");
    }

    @PostMapping(path = "/v1/fact", consumes = MediaType.APPLICATION_JSON_VALUE)
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    public FactResponse fact(
            @RequestBody(required = false) FactRequest request,
            @RequestHeader(name = USER_HEADER, required = false) String userId
    ) {
        if (request == null) {
            throw new BadRequestException("request body is required");
        }

        ValidatedFactRequest validatedRequest = request.validateAndNormalize(normalizeUserId(userId));

        if (diagnosticsSettings.enabled()) {
            log.info(
                    "event=fact_request_valid boundary={} factMode={} placeNameLength={} hasCountryContext={}",
                    validatedRequest.boundary(),
                    validatedRequest.factMode().wireValue(),
                    validatedRequest.placeName().length(),
                    validatedRequest.countryContext() != null
            );
        }

        String fact = openAiService.generateFact(validatedRequest);
        if (diagnosticsSettings.enabled()) {
            log.info(
                    "event=fact_request_success boundary={} factMode={} factLength={}",
                    validatedRequest.boundary(),
                    validatedRequest.factMode().wireValue(),
                    fact.length()
            );
        }
        return new FactResponse(fact);
    }

    @PostMapping(path = "/v1/speech", consumes = MediaType.APPLICATION_JSON_VALUE, produces = "audio/mpeg")
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    public ResponseEntity<byte[]> speech(@RequestBody(required = false) SpeechRequest request) {
        if (request == null) {
            throw new BadRequestException("request body is required");
        }

        ValidatedSpeechRequest validatedRequest = request.validateAndNormalize();
        if (diagnosticsSettings.enabled()) {
            log.info("event=speech_request_valid textLength={}", validatedRequest.text().length());
        }

        byte[] audio = elevenLabsSpeechService.generateSpeech(validatedRequest);
        return ResponseEntity.ok()
                .contentType(MediaType.valueOf("audio/mpeg"))
                .body(audio);
    }

    private static String normalizeUserId(String userId) {
        return UserIdSanitizer.normalizeAndValidate(userId);
    }
}
