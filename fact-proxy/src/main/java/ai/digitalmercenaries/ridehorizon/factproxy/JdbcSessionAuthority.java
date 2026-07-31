package ai.digitalmercenaries.ridehorizon.factproxy;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

@Component
class JdbcSessionAuthority implements SessionAuthority {
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final Base64.Encoder BASE64_URL = Base64.getUrlEncoder().withoutPadding();
    private static final Pattern KEY_ID_PATTERN = Pattern.compile("[A-Za-z0-9._:-]{4,128}");
    private static final Set<String> ALLOWED_ENVIRONMENTS = Set.of("production", "development");
    private static final String PURPOSE_ATTESTATION = "attestation";
    private static final String PURPOSE_ASSERTION = "assertion";
    private static final String SESSION_STATUS_ACTIVE = "active";
    private static final String SESSION_STATUS_REVOKED = "revoked";
    private static final String FAIL_INVALID = "invalid";
    private static final String FAIL_RATE_LIMIT = "rate_limit";

    private final JdbcTemplate jdbc;
    private final Clock clock;
    private final Duration challengeTtl;
    private final Duration verifiedSessionTtl;
    private final Duration fallbackSessionTtl;
    private final int verifiedFactDailyLimit;
    private final int verifiedSpeechCharDailyLimit;
    private final int fallbackFactDailyLimit;
    private final int fallbackSpeechCharDailyLimit;
    private final int globalFactDailyLimit;
    private final int globalSpeechCharDailyLimit;
    private final String operatorTokenHash;

    JdbcSessionAuthority(
            JdbcTemplate jdbc,
            Clock clock,
            @Value("${ridehorizon.attestation-challenge-ttl-seconds:300}") long challengeTtlSeconds,
            @Value("${ridehorizon.session-ttl-seconds:3600}") long verifiedSessionTtlSeconds,
            @Value("${ridehorizon.fallback-session-ttl-seconds:900}") long fallbackSessionTtlSeconds,
            @Value("${ridehorizon.verified-fact-daily-limit:180}") int verifiedFactDailyLimit,
            @Value("${ridehorizon.verified-speech-char-daily-limit:120000}") int verifiedSpeechCharDailyLimit,
            @Value("${ridehorizon.fallback-fact-daily-limit:20}") int fallbackFactDailyLimit,
            @Value("${ridehorizon.fallback-speech-char-daily-limit:12000}") int fallbackSpeechCharDailyLimit,
            @Value("${ridehorizon.global-fact-daily-limit:2000}") int globalFactDailyLimit,
            @Value("${ridehorizon.global-speech-char-daily-limit:250000}") int globalSpeechCharDailyLimit,
            @Value("${ridehorizon.proxy-token:}") String operatorToken
    ) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.challengeTtl = Duration.ofSeconds(Math.max(30, challengeTtlSeconds));
        this.verifiedSessionTtl = Duration.ofSeconds(Math.max(60, verifiedSessionTtlSeconds));
        this.fallbackSessionTtl = Duration.ofSeconds(Math.max(60, fallbackSessionTtlSeconds));
        this.verifiedFactDailyLimit = Math.max(1, verifiedFactDailyLimit);
        this.verifiedSpeechCharDailyLimit = Math.max(1, verifiedSpeechCharDailyLimit);
        this.fallbackFactDailyLimit = Math.max(1, fallbackFactDailyLimit);
        this.fallbackSpeechCharDailyLimit = Math.max(1, fallbackSpeechCharDailyLimit);
        this.globalFactDailyLimit = Math.max(1, globalFactDailyLimit);
        this.globalSpeechCharDailyLimit = Math.max(1, globalSpeechCharDailyLimit);
        this.operatorTokenHash = operatorToken == null || operatorToken.isBlank() ? null : hash(operatorToken);
    }

    @Override
    public AttestationChallenge issueAttestationChallenge(String environment) {
        return issueAttestationChallenge(PURPOSE_ATTESTATION, null, null, normalizeEnvironment(environment));
    }

    @Override
    public AssertionChallenge issueAssertionChallenge(String keyId) {
        String normalized = normalizeKeyId(keyId);
        if (normalized == null) {
            throw new ProofRejected("keyId is invalid");
        }
        UUID installationId = installationIdForKeyId(normalized);
        if (installationId == null) {
            throw new ProofRejected("installation not found");
        }
        String environment = installationEnvironment(installationId);
        return issueAssertionChallenge(PURPOSE_ASSERTION, installationId, normalized, environment);
    }

    @Override
    @Transactional
    public SessionToken registerAttestation(AttestationRegistrationRequest request) {
        throw new ProofRejected("App Attest verification is not enabled");
    }

    @Override
    @Transactional
    public SessionToken renewWithAssertion(AssertionRenewalRequest request) {
        throw new ProofRejected("App Attest verification is not enabled");
    }

    @Override
    public SessionToken issueFallbackSession(String reason, String quotaSubject) {
        String normalizedSubject = DeviceIdSanitizer.normalize(quotaSubject);
        if (normalizedSubject == null) {
            throw new BadRequestException("automatic access requires an installation identifier");
        }
        return issueSession(null, true, normalizeReason(reason), hash("fallback:" + normalizedSubject));
    }

    @Override
    public SessionAuthentication authenticate(String token) {
        String normalized = normalizeToken(token);
        if (normalized == null) {
            return null;
        }

        String tokenHash = hash(normalized);
        Instant now = clock.instant();

        List<SessionAuthentication> matches = resolveSessionForToken(tokenHash, now);

        if (!matches.isEmpty()) {
            SessionAuthentication authentication = matches.getFirst();
            UUID installationId = authentication.installationId();
            if (installationId != null && !isInstallationActive(installationId)) {
                return null;
            }

            try {
                jdbc.update("UPDATE rh_sessions SET last_used_at = ? WHERE token_hash = ?", timestamp(now), tokenHash);
            } catch (DataAccessException ex) {
                if (!isSchemaMissing(ex)) {
                    throw ex;
                }
            }
            return authentication;
        }

        if (operatorTokenHash != null && MessageDigest.isEqual(tokenHash.getBytes(StandardCharsets.UTF_8), operatorTokenHash.getBytes(StandardCharsets.UTF_8))) {
            return new SessionAuthentication(null, true, true, hash("operator"));
        }

        return null;
    }

    @Override
    @Transactional
    public void authorizeFact(SessionAuthentication auth) {
        authorize(auth, 1, 0);
    }

    @Override
    @Transactional
    public void authorizeSpeech(SessionAuthentication auth, int textLength) {
        if (textLength < 0) {
            throw new BadRequestException("speech text length is invalid");
        }
        authorize(auth, 0, textLength);
    }

    @Override
    public List<SessionAuthenticationSummary> listInstallations() {
        return jdbc.query(
                """
                        SELECT id, key_id, environment, status,
                               created_at, last_seen_at, revoked_at
                          FROM rh_installations
                         ORDER BY created_at DESC
                        """,
                (rs, rowNumber) -> new SessionAuthenticationSummary(
                        rs.getObject("id", UUID.class),
                        rs.getString("key_id"),
                        rs.getString("environment"),
                        rs.getString("status"),
                        instant(rs, "created_at"),
                        nullableInstant(rs, "last_seen_at"),
                        nullableInstant(rs, "revoked_at")
                )
        );
    }

    @Override
    @Transactional
    public boolean revoke(UUID installationId) {
        if (installationId == null) {
            return false;
        }
        int updated = jdbc.update(
                """
                        UPDATE rh_installations
                           SET revoked_at = ?,
                               status = ?,
                               last_assertion_error_category = NULL,
                               failure_category = ?
                         WHERE id = ?
                           AND revoked_at IS NULL
                        """,
                timestamp(clock.instant()),
                SESSION_STATUS_REVOKED,
                FAIL_INVALID,
                installationId
        );
        if (updated > 0) {
            revokeActiveSessions(installationId);
            return true;
        }
        return false;
    }

    private void authorize(SessionAuthentication auth, int factRequests, int speechChars) {
        if (auth == null) {
            throw new SessionAuthority.UnauthorizedAccess();
        }
        if (auth.installationId() == null && !auth.fallback()) {
            throw new BadRequestException("session is invalid");
        }
        if (auth.quotaSubjectHash() == null || auth.quotaSubjectHash().isBlank()) {
            throw new SessionAuthority.UnauthorizedAccess();
        }

        boolean fallback = auth.fallback();
        authorizeDailyUsage(auth.quotaSubjectHash(), auth.installationId(), fallback, factRequests, speechChars);
    }

    @Transactional
    void authorizeDailyUsage(
            String quotaSubjectHash,
            UUID installationId,
            boolean fallback,
            int factRequests,
            int speechChars
    ) {
        LocalDate today = LocalDate.now(clock);
        java.sql.Date bucketDate = java.sql.Date.valueOf(today);
        int perInstallFactLimit = fallback ? fallbackFactDailyLimit : verifiedFactDailyLimit;
        int perInstallSpeechLimit = fallback ? fallbackSpeechCharDailyLimit : verifiedSpeechCharDailyLimit;

        if (speechChars > perInstallSpeechLimit) {
            throw new QuotaExceeded(FAIL_RATE_LIMIT);
        }

        if (!isH2Database()) {
            int subjectUpdated = incrementSubjectUsageWithinLimit(
                    today,
                    quotaSubjectHash,
                    fallback,
                    factRequests,
                    speechChars,
                    perInstallFactLimit,
                    perInstallSpeechLimit
            );
            if (subjectUpdated == 0) {
                throw new QuotaExceeded(FAIL_RATE_LIMIT);
            }

            int globalUpdated = incrementGlobalUsageWithinLimit(today, factRequests, speechChars);
            if (globalUpdated == 0) {
                throw new QuotaExceeded(FAIL_RATE_LIMIT);
            }
            return;
        }

        int currentFactRequests = selectIntOrZero(
                "SELECT fact_requests FROM rh_usage_subject_buckets WHERE bucket_date = ? AND quota_subject_hash = ? AND is_fallback = ?",
                bucketDate,
                quotaSubjectHash,
                fallback
        );
        int currentSpeechChars = selectIntOrZero(
                "SELECT speech_characters FROM rh_usage_subject_buckets WHERE bucket_date = ? AND quota_subject_hash = ? AND is_fallback = ?",
                bucketDate,
                quotaSubjectHash,
                fallback
        );

        if (currentFactRequests + factRequests > perInstallFactLimit
                || currentSpeechChars + speechChars > perInstallSpeechLimit) {
            if (installationId != null) {
                jdbc.update("UPDATE rh_installations SET failure_category = ? WHERE id = ?", FAIL_RATE_LIMIT, installationId);
            }
            throw new QuotaExceeded(FAIL_RATE_LIMIT);
        }

        int globalFact = selectIntOrZero("SELECT fact_requests FROM rh_global_usage_buckets WHERE bucket_date = ?", bucketDate);
        int globalSpeech = selectIntOrZero("SELECT speech_characters FROM rh_global_usage_buckets WHERE bucket_date = ?", bucketDate);
        if (globalFact + factRequests > globalFactDailyLimit || globalSpeech + speechChars > globalSpeechCharDailyLimit) {
            throw new QuotaExceeded(FAIL_RATE_LIMIT);
        }

        upsertUsageBucket(today, quotaSubjectHash, fallback, factRequests, speechChars);
        upsertGlobalUsageBucket(today, factRequests, speechChars);
    }

    private int incrementSubjectUsageWithinLimit(
            LocalDate bucketDate,
            String quotaSubjectHash,
            boolean fallback,
            int factRequests,
            int speechChars,
            int factLimit,
            int speechLimit
    ) {
        return jdbc.update(
                """
                        INSERT INTO rh_usage_subject_buckets (
                            bucket_date, quota_subject_hash, is_fallback,
                            fact_requests, fact_input_characters, speech_characters, updated_at
                        ) VALUES (?, ?, ?, ?, 0, ?, ?)
                        ON CONFLICT (bucket_date, quota_subject_hash, is_fallback)
                        DO UPDATE SET fact_requests = rh_usage_subject_buckets.fact_requests + EXCLUDED.fact_requests,
                                      speech_characters = rh_usage_subject_buckets.speech_characters + EXCLUDED.speech_characters,
                                      updated_at = EXCLUDED.updated_at
                              WHERE rh_usage_subject_buckets.fact_requests + EXCLUDED.fact_requests <= ?
                                AND rh_usage_subject_buckets.speech_characters + EXCLUDED.speech_characters <= ?
                        """,
                java.sql.Date.valueOf(bucketDate),
                quotaSubjectHash,
                fallback,
                factRequests,
                speechChars,
                timestamp(clock.instant()),
                factLimit,
                speechLimit
        );
    }

    private int incrementGlobalUsageWithinLimit(LocalDate bucketDate, int factRequests, int speechChars) {
        return jdbc.update(
                """
                        INSERT INTO rh_global_usage_buckets (
                            bucket_date, fact_requests, speech_characters, updated_at
                        ) VALUES (?, ?, ?, ?)
                        ON CONFLICT (bucket_date)
                        DO UPDATE SET fact_requests = rh_global_usage_buckets.fact_requests + EXCLUDED.fact_requests,
                                      speech_characters = rh_global_usage_buckets.speech_characters + EXCLUDED.speech_characters,
                                      updated_at = EXCLUDED.updated_at
                              WHERE rh_global_usage_buckets.fact_requests + EXCLUDED.fact_requests <= ?
                                AND rh_global_usage_buckets.speech_characters + EXCLUDED.speech_characters <= ?
                        """,
                java.sql.Date.valueOf(bucketDate),
                factRequests,
                speechChars,
                timestamp(clock.instant()),
                globalFactDailyLimit,
                globalSpeechCharDailyLimit
        );
    }

    private List<SessionAuthentication> resolveSessionForToken(String tokenHash, Instant now) {
        try {
            return jdbc.query(
                    """
                            SELECT s.installation_id, s.is_fallback, s.operator_token, s.quota_subject_hash
                              FROM rh_sessions s
                              LEFT JOIN rh_installations i
                                ON i.id = s.installation_id
                             WHERE s.token_hash = ?
                               AND s.revoked_at IS NULL
                               AND s.expires_at > ?
                            """,
                    (rs, rowNumber) -> {
                        boolean fallback = rs.getBoolean("is_fallback");
                        String quotaSubjectHash = rs.getString("quota_subject_hash");
                        if (quotaSubjectHash == null || quotaSubjectHash.isBlank()) {
                            quotaSubjectHash = fallback ? hash("legacy-fallback") : null;
                        }
                        return new SessionAuthentication(
                                rs.getObject("installation_id", UUID.class),
                                fallback,
                                rs.getBoolean("operator_token"),
                                quotaSubjectHash
                        );
                    },
                    tokenHash,
                    timestamp(now)
            );
        } catch (DataAccessException ex) {
            if (isSchemaMissing(ex)) {
                return List.of();
            }
            throw ex;
        }
    }

    private static boolean isSchemaMissing(DataAccessException ex) {
        String message = ex.getMessage() == null ? "" : ex.getMessage().toLowerCase(java.util.Locale.ROOT);
        return message.contains("does not exist")
                || (message.contains("table") && (message.contains("not found") || message.contains("doesn't exist") || message.contains("unknown")))
                || (message.contains("relation") && message.contains("does not exist"));
    }

    private void upsertUsageBucket(
            LocalDate bucketDate,
            String quotaSubjectHash,
            boolean fallback,
            int factRequests,
            int speechChars
    ) {
        if (isH2Database()) {
            int updated = jdbc.update(
                    """
                            UPDATE rh_usage_subject_buckets
                               SET fact_requests = fact_requests + ?,
                                   speech_characters = speech_characters + ?,
                                   updated_at = ?
                             WHERE bucket_date = ?
                               AND quota_subject_hash = ?
                               AND is_fallback = ?
                            """,
                    factRequests,
                    speechChars,
                    timestamp(clock.instant()),
                    java.sql.Date.valueOf(bucketDate),
                    quotaSubjectHash,
                    fallback
            );
            if (updated == 0) {
                jdbc.update(
                        """
                                INSERT INTO rh_usage_subject_buckets (
                                    bucket_date, quota_subject_hash, is_fallback,
                                    fact_requests, fact_input_characters, speech_characters, updated_at
                                ) VALUES (?, ?, ?, ?, 0, ?, ?)
                                """,
                        java.sql.Date.valueOf(bucketDate),
                        quotaSubjectHash,
                        fallback,
                        factRequests,
                        speechChars,
                        timestamp(clock.instant())
                );
            }
            return;
        }

        jdbc.update(
                """
                        INSERT INTO rh_usage_subject_buckets (
                            bucket_date, quota_subject_hash, is_fallback,
                            fact_requests, fact_input_characters, speech_characters, updated_at
                        ) VALUES (?, ?, ?, ?, 0, ?, ?)
                        ON CONFLICT (bucket_date, quota_subject_hash, is_fallback)
                        DO UPDATE SET fact_requests = rh_usage_subject_buckets.fact_requests + EXCLUDED.fact_requests,
                                      speech_characters = rh_usage_subject_buckets.speech_characters + EXCLUDED.speech_characters,
                                      updated_at = EXCLUDED.updated_at
                        """,
                java.sql.Date.valueOf(bucketDate),
                quotaSubjectHash,
                fallback,
                factRequests,
                speechChars,
                timestamp(clock.instant())
        );
    }

    private void upsertGlobalUsageBucket(LocalDate bucketDate, int factRequests, int speechChars) {
        if (isH2Database()) {
            int updated = jdbc.update(
                    """
                            UPDATE rh_global_usage_buckets
                               SET fact_requests = fact_requests + ?,
                                   speech_characters = speech_characters + ?,
                                   updated_at = ?
                             WHERE bucket_date = ?
                            """,
                    factRequests,
                    speechChars,
                    timestamp(clock.instant()),
                    java.sql.Date.valueOf(bucketDate)
            );
            if (updated == 0) {
                jdbc.update(
                        """
                                INSERT INTO rh_global_usage_buckets (
                                    bucket_date, fact_requests, speech_characters, updated_at
                                ) VALUES (?, ?, ?, ?)
                                """,
                        java.sql.Date.valueOf(bucketDate),
                        factRequests,
                        speechChars,
                        timestamp(clock.instant())
                );
            }
            return;
        }

        jdbc.update(
                """
                        INSERT INTO rh_global_usage_buckets (
                            bucket_date,
                            fact_requests,
                            speech_characters,
                            updated_at
                        ) VALUES (?, ?, ?, ?)
                        ON CONFLICT (bucket_date)
                        DO UPDATE SET fact_requests = rh_global_usage_buckets.fact_requests + EXCLUDED.fact_requests,
                                      speech_characters = rh_global_usage_buckets.speech_characters + EXCLUDED.speech_characters,
                                      updated_at = EXCLUDED.updated_at
                        """,
                java.sql.Date.valueOf(bucketDate),
                factRequests,
                speechChars,
                timestamp(clock.instant())
        );
    }

    private boolean isH2Database() {
        try (var connection = jdbc.getDataSource().getConnection()) {
            return "H2".equalsIgnoreCase(connection.getMetaData().getDatabaseProductName());
        } catch (SQLException ex) {
            throw new IllegalStateException("Unable to identify quota database", ex);
        }
    }

    private AttestationChallenge issueAttestationChallenge(String purpose, UUID installationId, String keyId, String environment) {
        return buildChallenge(AttestationChallenge.class, purpose, installationId, keyId, environment);
    }

    private AssertionChallenge issueAssertionChallenge(String purpose, UUID installationId, String keyId, String environment) {
        return buildChallenge(AssertionChallenge.class, purpose, installationId, keyId, environment);
    }

    private <T> T buildChallenge(Class<T> type, String purpose, UUID installationId, String keyId, String environment) {
        String challenge = randomToken("rh_challenge_");
        String challengeHash = hash(challenge);
        UUID challengeId = UUID.randomUUID();
        Instant now = clock.instant();
        Instant expiresAt = now.plus(challengeTtl);

        jdbc.update(
                """
                        INSERT INTO rh_challenges
                        (id, challenge_hash, purpose, installation_id, key_id, environment, created_at, expires_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                challengeId,
                challengeHash,
                purpose,
                installationId,
                keyId,
                environment,
                timestamp(now),
                timestamp(expiresAt)
        );

        if (type == AssertionChallenge.class) {
            return type.cast(new AssertionChallenge(challengeId, challenge, expiresAt));
        }
        return type.cast(new AttestationChallenge(challengeId, challenge, expiresAt));
    }

    private ChallengeRow consumeChallenge(UUID challengeId, String purpose, UUID expectedInstallationId, String expectedKeyId) {
        Instant now = clock.instant();
        List<ChallengeRow> rows = jdbc.query(
                """
                        SELECT id, purpose, installation_id, key_id, environment, attempts
                          FROM rh_challenges
                         WHERE id = ?
                           AND purpose = ?
                           AND consumed_at IS NULL
                           AND expires_at > ?
                        """,
                (rs, rowNumber) -> new ChallengeRow(
                        rs.getObject("id", UUID.class),
                        rs.getString("purpose"),
                        rs.getObject("installation_id", UUID.class),
                        rs.getString("key_id"),
                        rs.getString("environment"),
                        rs.getInt("attempts")
                ),
                challengeId,
                purpose,
                timestamp(now)
        );

        if (rows.size() != 1) {
            throw new ChallengeInvalid();
        }
        ChallengeRow challenge = rows.getFirst();
        if (expectedInstallationId != null && !expectedInstallationId.equals(challenge.installationId())) {
            throw new ChallengeInvalid("challenge installation mismatch");
        }
        if (expectedKeyId != null && !expectedKeyId.equals(challenge.keyId())) {
            throw new ChallengeInvalid("challenge key mismatch");
        }

        int consumed = jdbc.update(
                """
                        UPDATE rh_challenges
                           SET consumed_at = ?, attempts = attempts + 1, last_attempt_at = ?
                         WHERE id = ?
                           AND consumed_at IS NULL
                        """,
                timestamp(now),
                timestamp(now),
                challengeId
        );
        if (consumed != 1) {
            throw new ChallengeInvalid();
        }
        return challenge;
    }

    private SessionToken issueSession(
            UUID installationId,
            boolean fallback,
            String reason,
            String quotaSubjectHash
    ) {
        if (installationId != null && !isInstallationActive(installationId)) {
            throw new ProofRejected("installation not found");
        }

        String token = randomToken(fallback ? "rh_fallback_" : "rh_session_");
        String tokenHash = hash(token);
        Duration ttl = fallback ? fallbackSessionTtl : verifiedSessionTtl;
        Instant now = clock.instant();
        Instant expiresAt = now.plus(ttl);

        jdbc.update(
                """
                        INSERT INTO rh_sessions
                            (id, installation_id, is_fallback, operator_token,
                             failure_reason, token_hash, quota_subject_hash, created_at, expires_at)
                        VALUES (?, ?, ?, false, ?, ?, ?, ?, ?)
                        """,
                UUID.randomUUID(),
                installationId,
                fallback,
                reason,
                tokenHash,
                quotaSubjectHash,
                timestamp(now),
                timestamp(expiresAt)
        );
        return new SessionToken(token, expiresAt, fallback);
    }

    private void revokeActiveSessions(UUID installationId) {
        jdbc.update(
                """
                        UPDATE rh_sessions
                           SET revoked_at = ?
                         WHERE installation_id = ?
                           AND revoked_at IS NULL
                        """,
                timestamp(clock.instant()),
                installationId
        );
    }

    private UUID upsertInstallation(String keyId, String environment) {
        UUID existing = installationIdForKeyId(keyId);
        if (existing != null) {
            jdbc.update(
                    """
                            UPDATE rh_installations
                               SET environment = ?,
                                   status = ?,
                                   last_seen_at = ?,
                                   revoked_at = NULL
                             WHERE id = ?
                            """,
                    environment,
                    SESSION_STATUS_ACTIVE,
                    timestamp(clock.instant()),
                    existing
            );
            return existing;
        }

        UUID id = UUID.randomUUID();
        jdbc.update(
                """
                        INSERT INTO rh_installations
                            (id, key_id, environment, status, created_at, last_seen_at, assertion_counter)
                        VALUES (?, ?, ?, ?, ?, ?, 0)
                        """,
                id,
                keyId,
                environment,
                SESSION_STATUS_ACTIVE,
                timestamp(clock.instant()),
                timestamp(clock.instant())
        );
        return id;
    }

    private void setInstallationActive(UUID installationId) {
        jdbc.update(
                """
                        UPDATE rh_installations
                           SET status = ?,
                               last_seen_at = ?
                         WHERE id = ?
                        """,
                SESSION_STATUS_ACTIVE,
                timestamp(clock.instant()),
                installationId
        );
    }

    private void clearLastErrorState(UUID installationId) {
        jdbc.update(
                """
                        UPDATE rh_installations
                           SET last_assertion_error_category = NULL,
                               failure_category = NULL
                         WHERE id = ?
                        """,
                installationId
        );
    }

    private void markInstallationCounterRejection(UUID installationId) {
        jdbc.update(
                """
                        UPDATE rh_installations
                           SET last_assertion_error_category = ?
                         WHERE id = ?
                        """,
                FAIL_INVALID,
                installationId
        );
    }

    private long latestAssertionCounter(UUID installationId) {
        List<Long> rows = jdbc.query(
                "SELECT assertion_counter FROM rh_installations WHERE id = ?",
                (rs, rowNumber) -> rs.getLong("assertion_counter"),
                installationId
        );
        return rows.isEmpty() ? 0L : rows.getFirst();
    }

    private void updateInstallationCounter(UUID installationId, long assertionCounter) {
        jdbc.update(
                """
                        UPDATE rh_installations
                           SET assertion_counter = ?,
                               last_seen_at = ?,
                               status = ?
                         WHERE id = ?
                        """,
                assertionCounter,
                timestamp(clock.instant()),
                SESSION_STATUS_ACTIVE,
                installationId
        );
    }

    private UUID installationIdForKeyId(String keyId) {
        List<UUID> rows = jdbc.query(
                "SELECT id FROM rh_installations WHERE key_id = ? AND revoked_at IS NULL",
                (rs, rowNumber) -> rs.getObject("id", UUID.class),
                keyId
        );
        return rows.isEmpty() ? null : rows.getFirst();
    }

    private boolean isInstallationActive(UUID installationId) {
        List<UUID> rows = jdbc.query(
                "SELECT id FROM rh_installations WHERE id = ? AND revoked_at IS NULL",
                (rs, rowNumber) -> rs.getObject("id", UUID.class),
                installationId
        );
        return !rows.isEmpty();
    }

    private String installationEnvironment(UUID installationId) {
        List<String> rows = jdbc.query(
                "SELECT environment FROM rh_installations WHERE id = ?",
                (rs, rowNumber) -> rs.getString("environment"),
                installationId
        );
        if (rows.isEmpty()) {
            return "production";
        }
        return rows.getFirst();
    }

    private static String randomToken(String prefix) {
        byte[] bytes = new byte[32];
        SECURE_RANDOM.nextBytes(bytes);
        return prefix + BASE64_URL.encodeToString(bytes);
    }

    private static String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException impossible) {
            throw new IllegalStateException("SHA-256 is unavailable", impossible);
        }
    }

    private static String normalizeToken(String token) {
        if (token == null) {
            return null;
        }
        String trimmed = token.trim();
        if (trimmed.isBlank() || trimmed.length() > 512) {
            return null;
        }
        return trimmed;
    }

    private static String normalizeKeyId(String keyId) {
        if (keyId == null) {
            return null;
        }
        String trimmed = keyId.trim();
        return KEY_ID_PATTERN.matcher(trimmed).matches() ? trimmed : null;
    }

    private static String normalizeEnvironment(String environment) {
        if (environment == null || environment.isBlank()) {
            return "production";
        }
        String normalized = environment.trim().toLowerCase(Locale.ROOT);
        return ALLOWED_ENVIRONMENTS.contains(normalized) ? normalized : "production";
    }

    private static String normalizeReason(String reason) {
        if (reason == null || reason.isBlank()) {
            return "restricted";
        }
        String normalized = reason.trim().toLowerCase(Locale.ROOT);
        return normalized.substring(0, Math.min(48, normalized.length()));
    }

    private void validateAttestationRequest(AttestationRegistrationRequest request) {
        if (request == null) {
            throw new BadRequestException("request body is required");
        }
        if (normalizeKeyId(request.keyId()) == null) {
            throw new ProofRejected("keyId is required");
        }
        if (request.challengeId() == null) {
            throw new ChallengeInvalid("challengeId is required");
        }
        if (request.attestation() == null || request.attestation().isBlank()) {
            throw new ProofRejected("attestation is required");
        }
    }

    private void validateAssertionRequest(AssertionRenewalRequest request) {
        if (request == null) {
            throw new BadRequestException("request body is required");
        }
        if (normalizeKeyId(request.keyId()) == null) {
            throw new ProofRejected("keyId is required");
        }
        if (request.challengeId() == null) {
            throw new ChallengeInvalid("challengeId is required");
        }
        if (request.assertion() == null || request.assertion().isBlank()) {
            throw new ProofRejected("assertion is required");
        }
    }

    private static Timestamp timestamp(Instant value) {
        return Timestamp.from(value);
    }

    private int selectIntOrZero(String sql, Object... args) {
        List<Integer> rows = jdbc.query(sql, (rs, rowNumber) -> rs.getInt(1), args);
        return rows.isEmpty() ? 0 : rows.getFirst();
    }

    private static Instant instant(ResultSet rs, String column) throws SQLException {
        Timestamp value = rs.getTimestamp(column);
        return value == null ? null : value.toInstant();
    }

    private static Instant nullableInstant(ResultSet rs, String column) throws SQLException {
        Timestamp value = rs.getTimestamp(column);
        return value == null ? null : value.toInstant();
    }

    private record ChallengeRow(
            UUID challengeId,
            String purpose,
            UUID installationId,
            String keyId,
            String environment,
            int attempts
    ) {
    }

}
