package ai.digitalmercenaries.ridehorizon.factproxy;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import jakarta.servlet.http.HttpServletRequest;

import java.util.UUID;

@RestController
public class FactController {
    private static final Logger log = LoggerFactory.getLogger(FactController.class);
    private static final String USER_HEADER = "X-RideHorizon-User-Id";
    private static final String RIDE_HEADER = "X-RideHorizon-Ride-Id";
    private static final String PREVIOUS_RESPONSE_HEADER = "X-RideHorizon-Previous-Response-Id";
    private static final String RESPONSE_HEADER = "X-RideHorizon-Response-Id";

    private final OpenAiService openAiService;
    private final ElevenLabsSpeechService elevenLabsSpeechService;
    private final DiagnosticsSettings diagnosticsSettings;
    private final SessionAuthority sessions;

    public FactController(
            OpenAiService openAiService,
            ElevenLabsSpeechService elevenLabsSpeechService,
            DiagnosticsSettings diagnosticsSettings,
            SessionAuthority sessions
    ) {
        this.openAiService = openAiService;
        this.elevenLabsSpeechService = elevenLabsSpeechService;
        this.diagnosticsSettings = diagnosticsSettings;
        this.sessions = sessions;
    }

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("ok");
    }

    @PostMapping(path = "/v1/fact", consumes = MediaType.APPLICATION_JSON_VALUE)
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    public ResponseEntity<FactResponse> fact(
            @RequestBody(required = false) FactRequest request,
            @RequestHeader(name = USER_HEADER, required = false) String userId,
            @RequestHeader(name = RIDE_HEADER, required = false) String rideId,
            @RequestHeader(name = PREVIOUS_RESPONSE_HEADER, required = false) String previousResponseId,
            HttpServletRequest httpRequest
    ) {
        if (request == null) {
            throw new BadRequestException("request body is required");
        }

        ValidatedFactRequest validatedRequest = request.validateAndNormalize(normalizeUserId(userId));
        boolean linkedRideRequest = rideId != null && !rideId.isBlank();
        String normalizedPreviousResponseId = null;
        if (linkedRideRequest) {
            validateRideId(rideId);
            normalizedPreviousResponseId = normalizePreviousResponseId(previousResponseId);
        } else if (previousResponseId != null && !previousResponseId.isBlank()) {
            throw new BadRequestException("ride id is required with previous response id");
        }

        if (diagnosticsSettings.enabled()) {
            log.info(
                    "event=fact_request_valid boundary={} factMode={} placeNameLength={} hasCountryContext={}",
                    validatedRequest.boundary(),
                    validatedRequest.factMode().wireValue(),
                    validatedRequest.placeName().length(),
                    validatedRequest.countryContext() != null
            );
        }

        SessionAuthority.SessionAuthentication auth = (SessionAuthority.SessionAuthentication) httpRequest.getAttribute(
                ProxyAuthFilter.SESSION_AUTH_ATTRIBUTE
        );
        sessions.authorizeFact(auth);

        OpenAiService.GeneratedFact generatedFact = linkedRideRequest
                ? openAiService.generateFactWithLinkage(
                        validatedRequest,
                        normalizedPreviousResponseId
                )
                : openAiService.generateFactWithMetadata(validatedRequest);
        String fact = generatedFact.fact();
        if (diagnosticsSettings.enabled()) {
            log.info(
                    "event=fact_request_success boundary={} factMode={} factLength={} sourceCount={}",
                    validatedRequest.boundary(),
                    validatedRequest.factMode().wireValue(),
                    fact.length(),
                    generatedFact.sources().size()
            );
        }
        ResponseEntity.BodyBuilder response = ResponseEntity.ok();
        if (generatedFact.responseId() != null) {
            response.header(RESPONSE_HEADER, generatedFact.responseId());
        }
        return response.body(new FactResponse(fact, generatedFact.sources()));
    }

    @PostMapping(path = "/v1/speech", consumes = MediaType.APPLICATION_JSON_VALUE, produces = "audio/mpeg")
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    public ResponseEntity<byte[]> speech(
            @RequestBody(required = false) SpeechRequest request,
            HttpServletRequest httpRequest
    ) {
        SessionAuthority.SessionAuthentication auth = (SessionAuthority.SessionAuthentication) httpRequest.getAttribute(
                ProxyAuthFilter.SESSION_AUTH_ATTRIBUTE
        );

        if (request == null) {
            throw new BadRequestException("request body is required");
        }

        ValidatedSpeechRequest validatedRequest = request.validateAndNormalize();
        sessions.authorizeSpeech(auth, validatedRequest.text().length());

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

    private static void validateRideId(String rideId) {
        try {
            UUID.fromString(rideId);
        } catch (IllegalArgumentException ex) {
            throw new BadRequestException("ride id is invalid");
        }
    }

    private static String normalizePreviousResponseId(String previousResponseId) {
        if (previousResponseId == null || previousResponseId.isBlank()) {
            return null;
        }
        String normalized = previousResponseId.trim();
        if (normalized.length() > 200 || !normalized.matches("[A-Za-z0-9_-]+")) {
            throw new BadRequestException("previous response id is invalid");
        }
        return normalized;
    }
}
