CREATE INDEX rh_invite_codes_retention_idx
    ON rh_invite_codes (expires_at, consumed_at);

CREATE INDEX rh_device_credentials_retention_idx
    ON rh_device_credentials (expires_at, revoked_at);
