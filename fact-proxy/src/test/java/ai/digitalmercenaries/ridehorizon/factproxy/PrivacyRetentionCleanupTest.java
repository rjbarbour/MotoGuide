package ai.digitalmercenaries.ridehorizon.factproxy;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;

class PrivacyRetentionCleanupTest {
    @Test
    void deletesOnlyInviteAndCredentialRecordsPastRetentionWindows() {
        JdbcTemplate jdbc = jdbc();
        Instant now = Instant.parse("2026-07-18T00:00:00Z");
        Instant oldInvite = now.minusSeconds(25L * 60 * 60);
        Instant inviteBoundary = now.minusSeconds(24L * 60 * 60);
        Instant oldCredential = now.minusSeconds(31L * 24 * 60 * 60);
        Instant credentialBoundary = now.minusSeconds(30L * 24 * 60 * 60);
        jdbc.update("""
                INSERT INTO rh_invite_codes (id, code_hash, created_at, expires_at, consumed_at)
                VALUES (?, ?, ?, ?, ?)
                """, UUID.randomUUID(), "consumed-old", Timestamp.from(oldInvite), Timestamp.from(now.plusSeconds(3600)), Timestamp.from(oldInvite));
        jdbc.update("""
                INSERT INTO rh_invite_codes (id, code_hash, created_at, expires_at, consumed_at)
                VALUES (?, ?, ?, ?, NULL)
                """, UUID.randomUUID(), "expired-old", Timestamp.from(oldInvite), Timestamp.from(oldInvite));
        jdbc.update("""
                INSERT INTO rh_invite_codes (id, code_hash, created_at, expires_at, consumed_at)
                VALUES (?, ?, ?, ?, ?)
                """, UUID.randomUUID(), "at-boundary", Timestamp.from(inviteBoundary), Timestamp.from(inviteBoundary), Timestamp.from(inviteBoundary));
        jdbc.update("""
                INSERT INTO rh_invite_codes (id, code_hash, created_at, expires_at, consumed_at)
                VALUES (?, ?, ?, ?, NULL)
                """, UUID.randomUUID(), "active-invite", Timestamp.from(now), Timestamp.from(now.plusSeconds(3600)));
        jdbc.update("""
                INSERT INTO rh_device_credentials (id, token_hash, device_id, created_at, expires_at, revoked_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """, UUID.randomUUID(), "expired-credential", "old-device", Timestamp.from(oldCredential), Timestamp.from(oldCredential), null);
        jdbc.update("""
                INSERT INTO rh_device_credentials (id, token_hash, device_id, created_at, expires_at, revoked_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """, UUID.randomUUID(), "revoked-credential", "revoked-device", Timestamp.from(oldCredential), Timestamp.from(now.plusSeconds(3600)), Timestamp.from(oldCredential));
        jdbc.update("""
                INSERT INTO rh_device_credentials (id, token_hash, device_id, created_at, expires_at, revoked_at)
                VALUES (?, ?, ?, ?, ?, NULL)
                """, UUID.randomUUID(), "credential-boundary", "boundary-device", Timestamp.from(credentialBoundary), Timestamp.from(credentialBoundary));
        jdbc.update("""
                INSERT INTO rh_device_credentials (id, token_hash, device_id, created_at, expires_at, revoked_at)
                VALUES (?, ?, ?, ?, ?, NULL)
                """, UUID.randomUUID(), "active-credential", "active-device", Timestamp.from(now), Timestamp.from(now.plusSeconds(3600)));

        PrivacyRetentionCleanup cleanup = new PrivacyRetentionCleanup(
                jdbc,
                Clock.fixed(now, ZoneOffset.UTC),
                24,
                30
        );

        assertEquals(4, cleanup.cleanupExpiredRecords());
        assertEquals(2, jdbc.queryForObject("SELECT COUNT(*) FROM rh_invite_codes", Integer.class));
        assertEquals(2, jdbc.queryForObject("SELECT COUNT(*) FROM rh_device_credentials", Integer.class));
        assertEquals(1, countByValue(jdbc, "rh_invite_codes", "code_hash", "at-boundary"));
        assertEquals(1, countByValue(jdbc, "rh_invite_codes", "code_hash", "active-invite"));
        assertEquals(1, countByValue(jdbc, "rh_device_credentials", "token_hash", "credential-boundary"));
        assertEquals(1, countByValue(jdbc, "rh_device_credentials", "token_hash", "active-credential"));
    }

    private static int countByValue(JdbcTemplate jdbc, String table, String column, String value) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM " + table + " WHERE " + column + " = ?", Integer.class, value);
    }

    private static JdbcTemplate jdbc() {
        DriverManagerDataSource dataSource = new DriverManagerDataSource(
                "jdbc:h2:mem:privacy-retention-" + UUID.randomUUID() + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE",
                "sa",
                ""
        );
        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("""
                CREATE TABLE rh_invite_codes (
                    id UUID PRIMARY KEY,
                    code_hash VARCHAR(64) NOT NULL UNIQUE,
                    label VARCHAR(80),
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    consumed_at TIMESTAMP WITH TIME ZONE
                )
                """);
        jdbc.execute("""
                CREATE TABLE rh_device_credentials (
                    id UUID PRIMARY KEY,
                    token_hash VARCHAR(64) NOT NULL UNIQUE,
                    device_id VARCHAR(64) NOT NULL,
                    label VARCHAR(80),
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    last_used_at TIMESTAMP WITH TIME ZONE,
                    revoked_at TIMESTAMP WITH TIME ZONE
                )
                """);
        return jdbc;
    }
}
