package ai.digitalmercenaries.ridehorizon.factproxy;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import java.sql.Date;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;

class PrivacyRetentionCleanupTest {
    @Test
    void deletesOnlyRecordsPastTheirRetentionWindows() {
        JdbcTemplate jdbc = jdbc();
        Instant now = Instant.parse("2026-07-18T00:00:00Z");
        Instant oldSessionRecord = now.minusSeconds(31L * 24 * 60 * 60);
        Instant sessionBoundary = now.minusSeconds(30L * 24 * 60 * 60);
        Instant oldChallenge = now.minusSeconds(25L * 60 * 60);
        Instant challengeBoundary = now.minusSeconds(24L * 60 * 60);
        Instant oldUsage = now.minusSeconds(4L * 24 * 60 * 60);
        Instant usageBoundary = now.minusSeconds(3L * 24 * 60 * 60);

        insertChallenge(jdbc, "old", oldChallenge, oldChallenge);
        insertChallenge(jdbc, "boundary", challengeBoundary, challengeBoundary);
        insertSession(jdbc, "old", oldSessionRecord, oldSessionRecord);
        insertSession(jdbc, "boundary", sessionBoundary, sessionBoundary);
        insertInstallation(jdbc, "old", oldSessionRecord);
        insertInstallation(jdbc, "boundary", sessionBoundary);
        insertUsage(jdbc, "old", oldUsage);
        insertUsage(jdbc, "boundary", usageBoundary);
        insertGlobalUsage(jdbc, oldUsage);
        insertGlobalUsage(jdbc, usageBoundary);

        PrivacyRetentionCleanup cleanup = new PrivacyRetentionCleanup(
                jdbc,
                Clock.fixed(now, ZoneOffset.UTC),
                30,
                24,
                3
        );

        assertEquals(5, cleanup.cleanupExpiredRecords());
        assertEquals(1, count(jdbc, "rh_challenges"));
        assertEquals(1, count(jdbc, "rh_sessions"));
        assertEquals(1, count(jdbc, "rh_installations"));
        assertEquals(1, count(jdbc, "rh_usage_subject_buckets"));
        assertEquals(1, count(jdbc, "rh_global_usage_buckets"));
    }

    private static void insertChallenge(JdbcTemplate jdbc, String tag, Instant timestamp, Instant consumedAt) {
        jdbc.update("""
                INSERT INTO rh_challenges
                    (id, challenge_hash, purpose, created_at, expires_at, consumed_at)
                VALUES (?, ?, 'attestation', ?, ?, ?)
                """, UUID.randomUUID(), "challenge-" + tag, Timestamp.from(timestamp),
                Timestamp.from(timestamp), Timestamp.from(consumedAt));
    }

    private static void insertSession(JdbcTemplate jdbc, String tag, Instant timestamp, Instant revokedAt) {
        jdbc.update("""
                INSERT INTO rh_sessions
                    (id, token_hash, is_fallback, operator_token, created_at, expires_at, revoked_at)
                VALUES (?, ?, TRUE, FALSE, ?, ?, ?)
                """, UUID.randomUUID(), "session-" + tag, Timestamp.from(timestamp),
                Timestamp.from(timestamp), Timestamp.from(revokedAt));
    }

    private static void insertInstallation(JdbcTemplate jdbc, String tag, Instant lastSeenAt) {
        jdbc.update("""
                INSERT INTO rh_installations
                    (id, key_id, environment, status, created_at, last_seen_at)
                VALUES (?, ?, 'development', 'active', ?, ?)
                """, UUID.randomUUID(), "installation-" + tag, Timestamp.from(lastSeenAt), Timestamp.from(lastSeenAt));
    }

    private static void insertUsage(JdbcTemplate jdbc, String tag, Instant updatedAt) {
        jdbc.update("""
                INSERT INTO rh_usage_subject_buckets
                    (bucket_date, quota_subject_hash, is_fallback, updated_at)
                VALUES (?, ?, TRUE, ?)
                """, Date.valueOf(LocalDate.ofInstant(updatedAt, ZoneOffset.UTC)), "subject-" + tag, Timestamp.from(updatedAt));
    }

    private static void insertGlobalUsage(JdbcTemplate jdbc, Instant updatedAt) {
        jdbc.update("""
                INSERT INTO rh_global_usage_buckets (bucket_date, updated_at)
                VALUES (?, ?)
                """, Date.valueOf(LocalDate.ofInstant(updatedAt, ZoneOffset.UTC)), Timestamp.from(updatedAt));
    }

    private static int count(JdbcTemplate jdbc, String table) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM " + table, Integer.class);
    }

    private static JdbcTemplate jdbc() {
        DriverManagerDataSource dataSource = new DriverManagerDataSource(
                "jdbc:h2:mem:privacy-retention-" + UUID.randomUUID()
                        + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE",
                "sa",
                ""
        );
        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("""
                CREATE TABLE rh_challenges (
                    id UUID PRIMARY KEY,
                    challenge_hash VARCHAR(64) NOT NULL UNIQUE,
                    purpose VARCHAR(32) NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    consumed_at TIMESTAMP WITH TIME ZONE
                )
                """);
        jdbc.execute("""
                CREATE TABLE rh_sessions (
                    id UUID PRIMARY KEY,
                    token_hash VARCHAR(64) NOT NULL UNIQUE,
                    is_fallback BOOLEAN NOT NULL,
                    operator_token BOOLEAN NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    revoked_at TIMESTAMP WITH TIME ZONE
                )
                """);
        jdbc.execute("""
                CREATE TABLE rh_installations (
                    id UUID PRIMARY KEY,
                    key_id VARCHAR(128) NOT NULL UNIQUE,
                    environment VARCHAR(32) NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    last_seen_at TIMESTAMP WITH TIME ZONE,
                    revoked_at TIMESTAMP WITH TIME ZONE
                )
                """);
        jdbc.execute("""
                CREATE TABLE rh_usage_subject_buckets (
                    bucket_date DATE NOT NULL,
                    quota_subject_hash VARCHAR(64) NOT NULL,
                    is_fallback BOOLEAN NOT NULL,
                    fact_requests INTEGER NOT NULL DEFAULT 0,
                    fact_input_characters INTEGER NOT NULL DEFAULT 0,
                    speech_characters INTEGER NOT NULL DEFAULT 0,
                    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    PRIMARY KEY (bucket_date, quota_subject_hash, is_fallback)
                )
                """);
        jdbc.execute("""
                CREATE TABLE rh_global_usage_buckets (
                    bucket_date DATE PRIMARY KEY,
                    fact_requests INTEGER NOT NULL DEFAULT 0,
                    speech_characters INTEGER NOT NULL DEFAULT 0,
                    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
                )
                """);
        return jdbc;
    }
}
