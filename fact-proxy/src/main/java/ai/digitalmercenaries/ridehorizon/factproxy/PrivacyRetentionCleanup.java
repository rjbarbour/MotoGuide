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
    private final Duration inviteRetention;
    private final Duration credentialRetention;

    PrivacyRetentionCleanup(
            JdbcTemplate jdbc,
            Clock clock,
            @Value("${ridehorizon.invite-record-retention-hours:24}") long inviteRetentionHours,
            @Value("${ridehorizon.credential-record-retention-days:30}") long credentialRetentionDays
    ) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.inviteRetention = Duration.ofHours(Math.max(1, inviteRetentionHours));
        this.credentialRetention = Duration.ofDays(Math.max(1, credentialRetentionDays));
    }

    @Scheduled(
            initialDelayString = "${ridehorizon.retention-cleanup-initial-delay-ms:60000}",
            fixedDelayString = "${ridehorizon.retention-cleanup-delay-ms:21600000}"
    )
    @Transactional
    int cleanupExpiredRecords() {
        Instant now = clock.instant();
        Timestamp inviteCutoff = Timestamp.from(now.minus(inviteRetention));
        Timestamp credentialCutoff = Timestamp.from(now.minus(credentialRetention));

        int invitesDeleted = jdbc.update("""
                DELETE FROM rh_invite_codes
                 WHERE (consumed_at IS NOT NULL AND consumed_at < ?)
                    OR (consumed_at IS NULL AND expires_at < ?)
                """, inviteCutoff, inviteCutoff);
        int credentialsDeleted = jdbc.update("""
                DELETE FROM rh_device_credentials
                 WHERE expires_at < ?
                    OR (revoked_at IS NOT NULL AND revoked_at < ?)
                """, credentialCutoff, credentialCutoff);
        return invitesDeleted + credentialsDeleted;
    }
}
