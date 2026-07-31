CREATE INDEX rh_challenges_consumed_idx
    ON rh_challenges (consumed_at, expires_at);

CREATE INDEX rh_sessions_expires_idx
    ON rh_sessions (expires_at, revoked_at);

CREATE INDEX rh_sessions_created_idx
    ON rh_sessions (created_at);

CREATE INDEX rh_installations_last_seen_idx
    ON rh_installations (last_seen_at);

CREATE INDEX rh_usage_buckets_updated_idx
    ON rh_usage_buckets (updated_at);

CREATE INDEX rh_global_usage_buckets_updated_idx
    ON rh_global_usage_buckets (updated_at);
