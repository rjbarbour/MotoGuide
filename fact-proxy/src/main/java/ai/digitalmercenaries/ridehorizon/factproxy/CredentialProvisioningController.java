package ai.digitalmercenaries.ridehorizon.factproxy;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
final class CredentialProvisioningController {
    private final CredentialAuthority credentials;
    private final AdminAuthorizer adminAuthorizer;

    CredentialProvisioningController(CredentialAuthority credentials, AdminAuthorizer adminAuthorizer) {
        this.credentials = credentials;
        this.adminAuthorizer = adminAuthorizer;
    }

    @PostMapping("/admin/v1/invites")
    ResponseEntity<?> createInvite(HttpServletRequest request, @RequestBody CreateInviteRequest body) {
        ResponseEntity<?> rejection = rejectUnauthorizedAdmin(request);
        if (rejection != null) {
            return rejection;
        }
        CredentialAuthority.InviteIssue issue = credentials.issueInvite(body.label());
        return ResponseEntity.status(HttpStatus.CREATED).body(new InviteResponse(
                issue.inviteId(), issue.inviteCode(), issue.expiresAt()));
    }

    @PostMapping("/v1/provision")
    ResponseEntity<?> provision(@RequestBody ProvisionRequest body) {
        try {
            CredentialAuthority.IssuedCredential issued = credentials.redeem(body.inviteCode(), body.deviceId());
            return ResponseEntity.status(HttpStatus.CREATED).body(new ProvisionResponse(
                    issued.credentialId(), issued.credential(), issued.expiresAt()));
        } catch (CredentialAuthority.InvalidInviteException rejected) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(new ProvisionError("invalid_invite", "Invite is invalid or expired."));
        }
    }

    @GetMapping("/admin/v1/credentials")
    ResponseEntity<?> listCredentials(HttpServletRequest request) {
        ResponseEntity<?> rejection = rejectUnauthorizedAdmin(request);
        return rejection != null ? rejection : ResponseEntity.ok(credentials.listCredentials());
    }

    @DeleteMapping("/admin/v1/credentials/{credentialId}")
    ResponseEntity<?> revoke(HttpServletRequest request, @PathVariable UUID credentialId) {
        ResponseEntity<?> rejection = rejectUnauthorizedAdmin(request);
        if (rejection != null) {
            return rejection;
        }
        return credentials.revoke(credentialId)
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

    record CreateInviteRequest(String label) {
    }

    record InviteResponse(UUID inviteId, String inviteCode, Instant expiresAt) {
    }

    record ProvisionRequest(String inviteCode, String deviceId) {
    }

    record ProvisionResponse(UUID credentialId, String credential, Instant expiresAt) {
    }

    record ProvisionError(String code, String message) {
    }
}
