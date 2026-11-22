CREATE OR REPLACE PROCEDURE SKYPOINTS.SILVER.SP_CLEAN_SILVER_REDEMPTIONS_SOURCE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    bad_redemptions_count   INT;
    clean_redemptions_count INT;
BEGIN
    -- Ensure error_reason column exists
    ALTER TABLE bronze.redemptions_bad_records ADD COLUMN IF NOT EXISTS error_reason VARCHAR;

    -- Step 1: Remove duplicates from silver.silver_redemptions_source using ROW_NUMBER()
    CREATE OR REPLACE TABLE silver.silver_redemptions_source AS
    SELECT
        member_id,
        txn_id,
        txn_date,
        partner,
        miles_redeemed,
        status,
        feed_date,
        load_timestamp
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY COALESCE(NULLIF(TRIM(txn_id), ''''), UUID_STRING())
                ORDER BY load_timestamp DESC NULLS LAST
            ) AS rn
        FROM silver.silver_redemptions_source
    )
    WHERE rn = 1;

    -- Step 2: Quarantine invalid rows into bronze.redemptions_bad_records
    INSERT INTO bronze.redemptions_bad_records (
        member_id,
        txn_id,
        txn_date,
        partner,
        miles_redeemed,
        status,
        feed_date,
        load_timestamp,
        error_reason
    )
    WITH redemption_dq AS (
        SELECT
            *,
            ARRAY_TO_STRING(ARRAY_COMPACT([
                IFF(NULLIF(TRIM(member_id), '''') IS NULL OR TRY_TO_NUMBER(TRIM(member_id)) IS NULL OR TRY_TO_NUMBER(TRIM(member_id)) <= 0, ''INVALID_OR_NULL_MEMBER_ID'', NULL),
                IFF(NULLIF(TRIM(txn_id), '''') IS NULL OR NOT REGEXP_LIKE(TRIM(txn_id), ''^RX[A-Za-z0-9_-]+$''), ''INVALID_OR_NULL_TXN_ID'', NULL),
                IFF(txn_date IS NULL, ''NULL_OR_INVALID_TXN_DATE'', NULL),
                IFF(txn_date IS NOT NULL AND txn_date > CURRENT_DATE(), ''FUTURE_TXN_DATE'', NULL),
                IFF(NULLIF(TRIM(partner), '''') IS NULL, ''NULL_OR_EMPTY_PARTNER'', NULL),
                IFF(miles_redeemed IS NULL OR miles_redeemed <= 0, ''INVALID_MILES_REDEEMED'', NULL),
                IFF(NULLIF(TRIM(status), '''') IS NULL OR UPPER(TRIM(status)) NOT IN (''COMPLETED'', ''PENDING'', ''CANCELLED''), ''INVALID_STATUS'', NULL),
                IFF(feed_date IS NOT NULL AND txn_date IS NOT NULL AND feed_date < txn_date, ''FEED_DATE_BEFORE_TXN_DATE'', NULL)
            ]), ''; '') AS error_reason
        FROM silver.silver_redemptions_source
    )
    SELECT
        member_id,
        txn_id,
        txn_date::VARCHAR,
        partner,
        miles_redeemed,
        status,
        feed_date::VARCHAR,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        error_reason
    FROM redemption_dq
    WHERE error_reason <> '''';

    bad_redemptions_count := SQLROWCOUNT;

    -- Step 3: Delete quarantined rows from silver.silver_redemptions_source
    DELETE FROM silver.silver_redemptions_source
    WHERE NULLIF(TRIM(member_id), '''') IS NULL
       OR TRY_TO_NUMBER(TRIM(member_id)) IS NULL
       OR TRY_TO_NUMBER(TRIM(member_id)) <= 0
       OR NULLIF(TRIM(txn_id), '''') IS NULL
       OR NOT REGEXP_LIKE(TRIM(txn_id), ''^RX[A-Za-z0-9_-]+$'')
       OR txn_date IS NULL
       OR (txn_date IS NOT NULL AND txn_date > CURRENT_DATE())
       OR NULLIF(TRIM(partner), '''') IS NULL
       OR miles_redeemed IS NULL
       OR miles_redeemed <= 0
       OR NULLIF(TRIM(status), '''') IS NULL
       OR UPPER(TRIM(status)) NOT IN (''COMPLETED'', ''PENDING'', ''CANCELLED'')
       OR (feed_date IS NOT NULL AND txn_date IS NOT NULL AND feed_date < txn_date);

    SELECT COUNT(*) INTO :clean_redemptions_count FROM silver.silver_redemptions_source;

    RETURN ''silver_redemptions_source cleaned. Quarantined: '' || bad_redemptions_count || '', Clean remaining: '' || clean_redemptions_count;
END;
';