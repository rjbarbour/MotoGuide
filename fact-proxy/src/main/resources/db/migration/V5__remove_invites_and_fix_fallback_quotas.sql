ALTER TABLE rh_sessions
    ADD COLUMN quota_subject_hash VARCHAR(64);

CREATE TABLE rh_usage_subject_buckets (
    bucket_date DATE NOT NULL,
    quota_subject_hash VARCHAR(64) NOT NULL,
    is_fallback BOOLEAN NOT NULL DEFAULT FALSE,
    fact_requests INTEGER NOT NULL DEFAULT 0,
    fact_input_characters INTEGER NOT NULL DEFAULT 0,
    speech_characters INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (bucket_date, quota_subject_hash, is_fallback)
);

CREATE INDEX rh_usage_subject_buckets_updated_idx
    ON rh_usage_subject_buckets (updated_at);

DROP TABLE IF EXISTS rh_usage_buckets;
DROP TABLE IF EXISTS rh_device_credentials;
DROP TABLE IF EXISTS rh_invite_codes;
