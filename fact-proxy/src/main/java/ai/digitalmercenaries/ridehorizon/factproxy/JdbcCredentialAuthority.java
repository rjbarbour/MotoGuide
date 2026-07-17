package ai.digitalmercenaries.ridehorizon.factproxy;

import org.springframework.beans.factory.annotation.Value;
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
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;

@Component
public class JdbcCredentialAuthority implements CredentialAuthority {
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final Base64.Encoder BASE64_URL = Base64.getUrlEncoder().withoutPadding();

    private final JdbcTemplate jdbc;
    private final Clock clock;
    private final Duration inviteTtl;
    private final Duration credentialTtl;

    JdbcCredentialAuthority(
            JdbcTemplate jdbc,
            Clock clock,
            @Value("${ridehorizon.invite-ttl-hours:72}") long inviteTtlHours,
            @Value("${ridehorizon.credential-ttl-days:90}") long credentialTtlDays
    ) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.inviteTtl = Duration.ofHours(Math.max(1, inviteTtlHours));
        this.credentialTtl = Duration.ofDays(Math.max(1, credentialTtlDays));
    }

    @Override
    public InviteIssue issueInvite(String requestedLabel) {
        Instant now = clock.instant();
        UUID id = UUID.randomUUID();
        String code = randomCredential("rhi_");
        Instant expiresAt = now.plus(inviteTtl);
        jdbc.update("""
                        INSERT INTO rh_invite_codes (id, code_hash, label, created_at, expires_at)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                id, hash(code), normalizeLabel(requestedLabel), timestamp(now), timestamp(expiresAt));
        return new InviteIssue(id, code, expiresAt);
    }

    @Override
    @Transactional
    public IssuedCredential redeem(String inviteCode, String requestedDeviceId) {
        String deviceId = DeviceIdSanitizer.normalize(requestedDeviceId);
        if (!validSecretInput(inviteCode, "rhi_") || deviceId == null) {
            throw new InvalidInviteException();
        }

        List<InviteRow> matches = jdbc.query("""
                        SELECT id, label, expires_at, consumed_at
                        FROM rh_invite_codes
                        WHERE code_hash = ?
                        FOR UPDATE
                        """, (rs, rowNumber) -> inviteRow(rs), hash(inviteCode));
        Instant now = clock.instant();
        if (matches.size() != 1 || matches.getFirst().consumedAt() != null
                || !matches.getFirst().expiresAt().isAfter(now)) {
            throw new InvalidInviteException();
        }

        InviteRow invite = matches.getFirst();
        int consumed = jdbc.update("""
                        UPDATE rh_invite_codes SET consumed_at = ?
                        WHERE id = ? AND consumed_at IS NULL
                        """, timestamp(now), invite.id());
        if (consumed != 1) {
            throw new InvalidInviteException();
        }

        UUID credentialId = UUID.randomUUID();
        String credential = randomCredential("rh_");
        Instant expiresAt = now.plus(credentialTtl);
        jdbc.update("""
                        INSERT INTO rh_device_credentials
                            (id, token_hash, device_id, label, created_at, expires_at)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """, credentialId, hash(credential), deviceId, invite.label(), timestamp(now), timestamp(expiresAt));
        return new IssuedCredential(credentialId, credential, expiresAt);
    }

    @Override
    public boolean authenticate(String credential, String requestedDeviceId) {
        String deviceId = DeviceIdSanitizer.normalize(requestedDeviceId);
        if (!validSecretInput(credential, "rh_") || deviceId == null) {
            return false;
        }
        Instant now = clock.instant();
        List<UUID> matches = jdbc.query("""
                        SELECT id FROM rh_device_credentials
                        WHERE token_hash = ? AND device_id = ? AND revoked_at IS NULL AND expires_at > ?
                        """, (rs, rowNumber) -> rs.getObject("id", UUID.class),
                hash(credential), deviceId, timestamp(now));
        if (matches.size() != 1) {
            return false;
        }
        jdbc.update("""
                        UPDATE rh_device_credentials SET last_used_at = ?
                        WHERE id = ? AND (last_used_at IS NULL OR last_used_at < ?)
                        """, timestamp(now), matches.getFirst(), timestamp(now.minus(Duration.ofMinutes(5))));
        return true;
    }

    @Override
    public boolean revoke(UUID credentialId) {
        return jdbc.update("""
                        UPDATE rh_device_credentials SET revoked_at = ?
                        WHERE id = ? AND revoked_at IS NULL
                        """, timestamp(clock.instant()), credentialId) == 1;
    }

    @Override
    public List<CredentialSummary> listCredentials() {
        return jdbc.query("""
                        SELECT id, device_id, label, created_at, expires_at, last_used_at, revoked_at
                        FROM rh_device_credentials ORDER BY created_at DESC
                        """, (rs, rowNumber) -> new CredentialSummary(
                rs.getObject("id", UUID.class),
                rs.getString("device_id"),
                rs.getString("label"),
                instant(rs, "created_at"),
                instant(rs, "expires_at"),
                nullableInstant(rs, "last_used_at"),
                nullableInstant(rs, "revoked_at")
        ));
    }

    private static InviteRow inviteRow(ResultSet rs) throws SQLException {
        return new InviteRow(
                rs.getObject("id", UUID.class),
                rs.getString("label"),
                instant(rs, "expires_at"),
                nullableInstant(rs, "consumed_at")
        );
    }

    private static String randomCredential(String prefix) {
        byte[] bytes = new byte[32];
        SECURE_RANDOM.nextBytes(bytes);
        return prefix + BASE64_URL.encodeToString(bytes);
    }

    private static String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException impossible) {
            throw new IllegalStateException("SHA-256 is unavailable", impossible);
        }
    }

    private static boolean validSecretInput(String value, String prefix) {
        return value != null && value.startsWith(prefix) && value.length() <= 128;
    }

    private static String normalizeLabel(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String normalized = value.trim().replaceAll("[\\r\\n\\t]+", " ");
        return normalized.substring(0, Math.min(80, normalized.length()));
    }

    private static Timestamp timestamp(Instant value) {
        return Timestamp.from(value);
    }

    private static Instant instant(ResultSet rs, String column) throws SQLException {
        return rs.getTimestamp(column).toInstant();
    }

    private static Instant nullableInstant(ResultSet rs, String column) throws SQLException {
        Timestamp value = rs.getTimestamp(column);
        return value == null ? null : value.toInstant();
    }

    private record InviteRow(UUID id, String label, Instant expiresAt, Instant consumedAt) {
    }
}
