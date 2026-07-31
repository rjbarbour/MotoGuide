package ai.digitalmercenaries.ridehorizon.factproxy;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.UUID;

@RestController
final class SessionAccessController {
    private static final String DEVICE_ID_HEADER = "X-RideHorizon-Device-Id";
    private final SessionAuthority sessions;
    private final AdminAuthorizer adminAuthorizer;

    SessionAccessController(SessionAuthority sessions, AdminAuthorizer adminAuthorizer) {
        this.sessions = sessions;
        this.adminAuthorizer = adminAuthorizer;
    }

    @PostMapping("/v1/session/fallback")
    ResponseEntity<SessionResponse> fallback(
            @RequestBody(required = false) FallbackRequest request,
            HttpServletRequest httpRequest
    ) {
        String deviceId = DeviceIdSanitizer.normalize(httpRequest.getHeader(DEVICE_ID_HEADER));
        if (deviceId == null) {
            throw new BadRequestException("automatic access requires an installation identifier");
        }
        String reason = request == null ? null : request.reason();
        SessionAuthority.SessionToken token = sessions.issueFallbackSession(reason, deviceId);
        return ResponseEntity.ok(new SessionResponse(token.token(), token.expiresAt(), token.fallback()));
    }

    @GetMapping("/admin/v1/sessions")
    ResponseEntity<?> listInstallations(HttpServletRequest request) {
        ResponseEntity<?> rejection = rejectUnauthorizedAdmin(request);
        if (rejection != null) {
            return rejection;
        }
        return ResponseEntity.ok(sessions.listInstallations());
    }

    @DeleteMapping("/admin/v1/sessions/{installationId}")
    ResponseEntity<?> revoke(HttpServletRequest request, @PathVariable UUID installationId) {
        ResponseEntity<?> rejection = rejectUnauthorizedAdmin(request);
        if (rejection != null) {
            return rejection;
        }
        return sessions.revoke(installationId)
                ? ResponseEntity.noContent().build()
                : ResponseEntity.notFound().build();
    }

    private ResponseEntity<?> rejectUnauthorizedAdmin(HttpServletRequest request) {
        if (!adminAuthorizer.isConfigured()) {
            return ResponseEntity.notFound().build();
        }
        if (!adminAuthorizer.isAuthorized(request)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        return null;
    }

    record SessionResponse(String sessionToken, Instant expiresAt, boolean fallback) {
    }

    record FallbackRequest(String reason) {
    }
}
