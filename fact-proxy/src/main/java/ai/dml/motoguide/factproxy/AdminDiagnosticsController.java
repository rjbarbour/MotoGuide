package ai.dml.motoguide.factproxy;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AdminDiagnosticsController {
    private static final Logger log = LoggerFactory.getLogger(AdminDiagnosticsController.class);

    private final DiagnosticsSettings diagnosticsSettings;
    private final MotoGuideProperties properties;

    public AdminDiagnosticsController(DiagnosticsSettings diagnosticsSettings, MotoGuideProperties properties) {
        this.diagnosticsSettings = diagnosticsSettings;
        this.properties = properties;
    }

    @GetMapping("/admin/diagnostics")
    public ResponseEntity<DiagnosticsResponse> diagnostics(HttpServletRequest request) {
        ResponseEntity<DiagnosticsResponse> unauthorized = authorize(request);
        if (unauthorized != null) {
            return unauthorized;
        }
        return ResponseEntity.ok(new DiagnosticsResponse(diagnosticsSettings.enabled()));
    }

    @PutMapping("/admin/diagnostics")
    public ResponseEntity<DiagnosticsResponse> updateDiagnostics(
            HttpServletRequest request,
            @RequestBody DiagnosticsRequest diagnosticsRequest
    ) {
        ResponseEntity<DiagnosticsResponse> unauthorized = authorize(request);
        if (unauthorized != null) {
            return unauthorized;
        }
        boolean enabled = diagnosticsSettings.setEnabled(diagnosticsRequest.enabled());
        log.warn("event=diagnostics_updated enabled={}", enabled);
        return ResponseEntity.ok(new DiagnosticsResponse(enabled));
    }

    private ResponseEntity<DiagnosticsResponse> authorize(HttpServletRequest request) {
        String expected = properties.adminToken();
        if (expected == null || expected.isBlank()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        String prefix = "Bearer ";
        if (authorization == null || !authorization.startsWith(prefix)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String token = authorization.substring(prefix.length()).trim();
        if (!expected.equals(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        return null;
    }
}
