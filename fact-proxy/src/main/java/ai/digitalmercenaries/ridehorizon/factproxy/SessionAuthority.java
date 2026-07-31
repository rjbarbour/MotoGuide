package ai.digitalmercenaries.ridehorizon.factproxy;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

interface SessionAuthority {
    AttestationChallenge issueAttestationChallenge(String environment);

    AssertionChallenge issueAssertionChallenge(String keyId);

    SessionToken registerAttestation(AttestationRegistrationRequest request);

    SessionToken renewWithAssertion(AssertionRenewalRequest request);

    SessionToken issueFallbackSession(String reason, String quotaSubject);

    SessionAuthentication authenticate(String token);

    void authorizeFact(SessionAuthentication auth);

    void authorizeSpeech(SessionAuthentication auth, int textLength);

    List<SessionAuthenticationSummary> listInstallations();

    boolean revoke(UUID installationId);

    record AttestationChallenge(UUID challengeId, String challenge, Instant expiresAt) {
    }

    record AssertionChallenge(UUID challengeId, String challenge, Instant expiresAt) {
    }

    record SessionToken(String token, Instant expiresAt, boolean fallback) {
    }

    record SessionAuthentication(UUID installationId, boolean fallback, boolean operatorToken, String quotaSubjectHash) {
    }

    record SessionAuthenticationSummary(
            UUID installationId,
            String keyId,
            String environment,
            String status,
            Instant createdAt,
            Instant lastSeenAt,
            Instant revokedAt
    ) {
    }

    record AttestationRegistrationRequest(
            String keyId,
            UUID challengeId,
            String attestation,
            String clientData,
            String environment
    ) {
    }

    record AssertionRenewalRequest(
            String keyId,
            UUID challengeId,
            String assertion,
            long assertionCounter
    ) {
    }

    class ChallengeInvalid extends BadRequestException {
        ChallengeInvalid(String message) {
            super(message);
        }

        ChallengeInvalid() {
            super("Challenge is invalid");
        }
    }

    class ProofRejected extends BadRequestException {
        ProofRejected(String message) {
            super(message);
        }

        ProofRejected() {
            super("Proof is invalid");
        }
    }

    class QuotaExceeded extends RuntimeException {
        private final String category;

        QuotaExceeded(String category) {
            this.category = category;
        }

        String category() {
            return category;
        }
    }

    final class UnauthorizedAccess extends RuntimeException {
    }

    final class ProofMalformed extends BadRequestException {
        ProofMalformed(String message) {
            super(message);
        }

        ProofMalformed() {
            super("Session proof is invalid");
        }
    }
}
