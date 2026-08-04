package ai.digitalmercenaries.ridehorizon.factproxy;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

@Component
class PrivacyRetentionCleanup {
    private final JdbcTemplate jdbc;
    private final Clock clock;
    private final Duration sessionRetention;
    private final Duration challengeRetention;
    private final Duration usageRetention;

    PrivacyRetentionCleanup(
            JdbcTemplate jdbc,
            Clock clock,
            @Value("${ridehorizon.session-record-retention-days:30}") long sessionRetentionDays,
            @Value("${ridehorizon.challenge-record-retention-hours:24}") long challengeRetentionHours,
            @Value("${ridehorizon.fallback-usage-retention-days:3}") long usageRetentionDays
    ) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.sessionRetention = Duration.ofDays(Math.max(1, sessionRetentionDays));
        this.challengeRetention = Duration.ofHours(Math.max(1, challengeRetentionHours));
        this.usageRetention = Duration.ofDays(Math.max(1, usageRetentionDays));
    }

    @Scheduled(
            initialDelayString = "${ridehorizon.retention-cleanup-initial-delay-ms:60000}",
            fixedDelayString = "${ridehorizon.retention-cleanup-delay-ms:21600000}"
    )
    @Transactional
    int cleanupExpiredRecords() {
        Instant now = clock.instant();
        Timestamp sessionCutoff = Timestamp.from(now.minus(sessionRetention));
        Timestamp challengeCutoff = Timestamp.from(now.minus(challengeRetention));
        Timestamp usageCutoff = Timestamp.from(now.minus(usageRetention));

        int challengeDeleted = jdbc.update(
                """
                        DELETE FROM rh_challenges
                         WHERE (consumed_at IS NOT NULL AND consumed_at < ?)
                            OR expires_at < ?
                        """, challengeCutoff, challengeCutoff
        );
        int sessionsDeleted = jdbc.update(
                """
                        DELETE FROM rh_sessions
                         WHERE (revoked_at IS NOT NULL AND revoked_at < ?)
                            OR expires_at < ?
                        """, sessionCutoff, sessionCutoff
        );
        int installationsDeleted = jdbc.update(
                """
                        DELETE FROM rh_installations
                         WHERE (revoked_at IS NOT NULL AND revoked_at < ?)
                            OR (revoked_at IS NULL AND COALESCE(last_seen_at, created_at) < ?)
                        """, sessionCutoff, sessionCutoff
        );
        int usageDeleted = jdbc.update(
                """
                        DELETE FROM rh_usage_subject_buckets
                         WHERE updated_at < ?
                        """, usageCutoff
        );
        int globalUsageDeleted = jdbc.update(
                """
                        DELETE FROM rh_global_usage_buckets
                         WHERE updated_at < ?
                        """, usageCutoff
        );

        return challengeDeleted + sessionsDeleted + installationsDeleted + usageDeleted + globalUsageDeleted;
    }
}
