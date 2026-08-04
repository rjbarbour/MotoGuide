CREATE TABLE rh_installations (
    id UUID PRIMARY KEY,
    key_id VARCHAR(128) NOT NULL UNIQUE,
    environment VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_seen_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    assertion_counter BIGINT NOT NULL DEFAULT 0,
    last_assertion_error_category VARCHAR(64),
    failure_category VARCHAR(64)
);

CREATE TABLE rh_challenges (
    id UUID PRIMARY KEY,
    challenge_hash VARCHAR(64) NOT NULL UNIQUE,
    purpose VARCHAR(32) NOT NULL,
    installation_id UUID,
    key_id VARCHAR(128),
    environment VARCHAR(32),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    consumed_at TIMESTAMP WITH TIME ZONE,
    attempts INTEGER NOT NULL DEFAULT 0,
    last_attempt_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE rh_sessions (
    id UUID PRIMARY KEY,
    installation_id UUID,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    is_fallback BOOLEAN NOT NULL DEFAULT FALSE,
    operator_token BOOLEAN NOT NULL DEFAULT FALSE,
    failure_reason VARCHAR(64),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_used_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE rh_usage_buckets (
    bucket_date DATE NOT NULL,
    installation_id UUID,
    is_fallback BOOLEAN NOT NULL DEFAULT FALSE,
    fact_requests INTEGER NOT NULL DEFAULT 0,
    fact_input_characters INTEGER NOT NULL DEFAULT 0,
    speech_characters INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (bucket_date, installation_id, is_fallback)
);

CREATE TABLE rh_global_usage_buckets (
    bucket_date DATE PRIMARY KEY,
    fact_requests INTEGER NOT NULL DEFAULT 0,
    speech_characters INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX rh_installations_status_idx ON rh_installations (status, revoked_at);
CREATE INDEX rh_challenges_installation_idx ON rh_challenges (installation_id, consumed_at);
CREATE INDEX rh_sessions_installation_idx ON rh_sessions (installation_id, revoked_at);
