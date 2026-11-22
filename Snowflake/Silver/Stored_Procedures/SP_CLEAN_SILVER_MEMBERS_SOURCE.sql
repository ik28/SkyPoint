CREATE OR REPLACE PROCEDURE SKYPOINTS.SILVER.SP_CLEAN_SILVER_MEMBERS_SOURCE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    bad_members_count   INT;
    clean_members_count INT;
BEGIN
    ALTER TABLE bronze.members_bad_records ADD COLUMN IF NOT EXISTS error_reason VARCHAR;

    -- Step 1: Quarantine all invalid rows FIRST (so duplicate 300043 with bad DOB is quarantined, keeping the valid 300043)
    INSERT INTO bronze.members_bad_records (
        member_name,
        member_id,
        enrollment_date,
        last_flight_date,
        tier_code,
        agent_name,
        state,
        country,
        dob,
        is_active,
        load_timestamp,
        error_reason
    )
    WITH member_dq AS (
        SELECT
            *,
            ARRAY_TO_STRING(ARRAY_COMPACT([
                -- Mandatory (Y) columns
                IFF(NULLIF(TRIM(member_name), '''') IS NULL OR LENGTH(TRIM(member_name)) > 255, ''INVALID_OR_NULL_MEMBER_NAME'', NULL),
                IFF(member_id IS NULL OR member_id <= 0 OR LENGTH(TRIM(member_id::VARCHAR)) > 18, ''INVALID_OR_NULL_MEMBER_ID'', NULL),
                IFF(enrollment_date IS NULL, ''NULL_OR_INVALID_ENROLLMENT_DATE'', NULL),

                -- Optional (N) columns: allow NULL, validate only when non-null
                IFF(last_flight_date IS NOT NULL AND enrollment_date IS NOT NULL AND last_flight_date < enrollment_date, ''FLIGHT_BEFORE_ENROLLMENT'', NULL),
                IFF(last_flight_date IS NOT NULL AND last_flight_date > CURRENT_DATE(), ''FUTURE_LAST_FLIGHT_DATE'', NULL),
                IFF(NULLIF(TRIM(tier_code), '''') IS NOT NULL AND (LENGTH(TRIM(tier_code)) > 5 OR UPPER(TRIM(tier_code)) NOT IN (''SLV'', ''GLD'', ''PLT'')), ''INVALID_TIER_CODE'', NULL),
                IFF(NULLIF(TRIM(agent_name), '''') IS NOT NULL AND LENGTH(TRIM(agent_name)) > 255, ''AGENT_NAME_TOO_LONG'', NULL),
                IFF(NULLIF(TRIM(state), '''') IS NOT NULL AND LENGTH(TRIM(state)) > 5, ''INVALID_STATE_LENGTH'', NULL),
                IFF(NULLIF(TRIM(country), '''') IS NOT NULL AND LENGTH(TRIM(country)) > 5, ''INVALID_COUNTRY_LENGTH'', NULL),
                IFF(dob IS NOT NULL AND dob > CURRENT_DATE(), ''FUTURE_DOB'', NULL),
                IFF(NULLIF(TRIM(is_active), '''') IS NOT NULL AND (LENGTH(TRIM(is_active)) > 1 OR UPPER(TRIM(is_active)) NOT IN (''A'', ''I'')), ''INVALID_IS_ACTIVE_FLAG'', NULL)
            ]), ''; '') AS error_reason
        FROM silver.silver_members_source
    )
    SELECT
        member_name,
        member_id::VARCHAR,
        enrollment_date::VARCHAR,
        last_flight_date::VARCHAR,
        tier_code,
        agent_name,
        state,
        country,
        dob::VARCHAR,
        is_active,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        error_reason
    FROM member_dq
    WHERE error_reason <> '''';

    bad_members_count := SQLROWCOUNT;

    -- Step 2: Delete quarantined rows from silver.silver_members_source
    DELETE FROM silver.silver_members_source
    WHERE NULLIF(TRIM(member_name), '''') IS NULL
       OR LENGTH(TRIM(member_name)) > 255
       OR member_id IS NULL
       OR member_id <= 0
       OR LENGTH(TRIM(member_id::VARCHAR)) > 18
       OR enrollment_date IS NULL
       OR (last_flight_date IS NOT NULL AND enrollment_date IS NOT NULL AND last_flight_date < enrollment_date)
       OR (last_flight_date IS NOT NULL AND last_flight_date > CURRENT_DATE())
       OR (NULLIF(TRIM(tier_code), '''') IS NOT NULL AND (LENGTH(TRIM(tier_code)) > 5 OR UPPER(TRIM(tier_code)) NOT IN (''SLV'', ''GLD'', ''PLT'')))
       OR (NULLIF(TRIM(agent_name), '''') IS NOT NULL AND LENGTH(TRIM(agent_name)) > 255)
       OR (NULLIF(TRIM(state), '''') IS NOT NULL AND LENGTH(TRIM(state)) > 5)
       OR (NULLIF(TRIM(country), '''') IS NOT NULL AND LENGTH(TRIM(country)) > 5)
       OR (dob IS NOT NULL AND dob > CURRENT_DATE())
       OR (NULLIF(TRIM(is_active), '''') IS NOT NULL AND (LENGTH(TRIM(is_active)) > 1 OR UPPER(TRIM(is_active)) NOT IN (''A'', ''I'')));

    -- Step 3: Deduplicate remaining valid rows by member_id
    CREATE OR REPLACE TABLE silver.silver_members_source AS
    SELECT
        member_name,
        member_id,
        enrollment_date,
        last_flight_date,
        tier_code,
        agent_name,
        dob,
        is_active,
        country,
        state,
        load_timestamp
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY member_id
                ORDER BY last_flight_date DESC NULLS LAST, load_timestamp DESC NULLS LAST
            ) AS rn
        FROM silver.silver_members_source
    )
    WHERE rn = 1;

    SELECT COUNT(*) INTO :clean_members_count FROM silver.silver_members_source;

    RETURN ''silver_members_source cleaned. Quarantined: '' || bad_members_count || '', Clean remaining: '' || clean_members_count;
END;
';