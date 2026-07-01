package ai.dml.motoguide.factproxy;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class FactController {
    private static final Logger log = LoggerFactory.getLogger(FactController.class);

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

    @PostMapping("/v1/fact")
    // Contract: see /Users/rob_dev/DocsLocal/motoguide/repo/FACT_PROXY_OPENAPI.yaml.
    public FactResponse fact(@RequestBody FactRequest request) {
        request.validate();
        String placeName = request.validatedPlaceName();
        String countryContext = request.validatedCountryContext();
        if (diagnosticsSettings.enabled()) {
            log.info(
                    "event=fact_request_valid boundary={} placeNameLength={} hasCountryContext={}",
                    request.boundary(),
                    placeName.length(),
                    countryContext != null
            );
        }

        String fact = openAiService.generateFact(request);
        if (diagnosticsSettings.enabled()) {
            log.info("event=fact_request_success boundary={} factLength={}", request.boundary(), fact.length());
        }
        return new FactResponse(fact);
    }
}
