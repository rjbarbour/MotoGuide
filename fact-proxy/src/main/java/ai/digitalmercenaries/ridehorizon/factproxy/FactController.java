package ai.digitalmercenaries.ridehorizon.factproxy;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
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
    public FactResponse fact(
            @RequestBody(required = false) FactRequest request,
            @RequestHeader(name = USER_HEADER, required = false) String userId,
            @RequestHeader(name = RIDE_HEADER, required = false) String rideId,
            HttpServletRequest httpRequest
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

        SessionAuthority.SessionAuthentication auth = (SessionAuthority.SessionAuthentication) httpRequest.getAttribute(
                ProxyAuthFilter.SESSION_AUTH_ATTRIBUTE
        );
        sessions.authorizeFact(auth);

        OpenAiService.RideConversation rideConversation = rideConversation(auth, rideId, false);
        String fact = rideConversation == null
                ? openAiService.generateFact(validatedRequest)
                : openAiService.generateFact(validatedRequest, rideConversation);
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

    @DeleteMapping("/v1/ride/conversation")
    public ResponseEntity<Void> endRideConversation(
            @RequestHeader(name = RIDE_HEADER) String rideId,
            HttpServletRequest httpRequest
    ) {
        SessionAuthority.SessionAuthentication auth = (SessionAuthority.SessionAuthentication) httpRequest.getAttribute(
                ProxyAuthFilter.SESSION_AUTH_ATTRIBUTE
        );
        openAiService.endRideConversation(rideConversation(auth, rideId, true));
        return ResponseEntity.noContent().build();
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

    private static OpenAiService.RideConversation rideConversation(
            SessionAuthority.SessionAuthentication auth,
            String rideId,
            boolean required
    ) {
        if (rideId == null || rideId.isBlank()) {
            if (required) {
                throw new BadRequestException("ride id is required");
            }
            return null;
        }
        try {
            return new OpenAiService.RideConversation(auth.quotaSubjectHash(), UUID.fromString(rideId));
        } catch (IllegalArgumentException ex) {
            throw new BadRequestException("ride id is invalid");
        }
    }
}
