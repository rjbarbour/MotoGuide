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
    private final DiagnosticsSettings diagnosticsSettings;

    public FactController(OpenAiService openAiService, DiagnosticsSettings diagnosticsSettings) {
        this.openAiService = openAiService;
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

    private static String normalizeUserId(String userId) {
        return UserIdSanitizer.normalizeAndValidate(userId);
    }
}
