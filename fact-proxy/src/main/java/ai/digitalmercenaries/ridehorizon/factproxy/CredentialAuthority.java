package ai.digitalmercenaries.ridehorizon.factproxy;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

interface CredentialAuthority {
    InviteIssue issueInvite(String label);

    IssuedCredential redeem(String inviteCode, String deviceId);

    boolean authenticate(String credential, String deviceId);

    boolean revoke(UUID credentialId);

    List<CredentialSummary> listCredentials();

    record InviteIssue(UUID inviteId, String inviteCode, Instant expiresAt) {
    }

    record IssuedCredential(UUID credentialId, String credential, Instant expiresAt) {
    }

    record CredentialSummary(
            UUID credentialId,
            String deviceId,
            String label,
            Instant createdAt,
            Instant expiresAt,
            Instant lastUsedAt,
            Instant revokedAt
    ) {
    }

    final class InvalidInviteException extends RuntimeException {
        InvalidInviteException() {
            super("Invite is invalid or expired");
        }
    }
}
