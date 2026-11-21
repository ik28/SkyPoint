CREATE OR REPLACE PROCEDURE SKYPOINTS.SILVER.SP_LOAD_SILVER_MEMBERS_SOURCE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    members_watermark TIMESTAMP_NTZ;
    members_inserted  INT;
BEGIN
    -- 1. Fetch last_load_timestamp watermark from ingestion_control
    SELECT COALESCE(MAX(last_load_timestamp), ''1900-01-01 00:00:00''::TIMESTAMP_NTZ)
      INTO :members_watermark
      FROM ingestion_control
     WHERE UPPER(TRIM(table_name)) = ''MEMBERS_CLEAN'';

    -- 2. Truncate silver_members_source
    TRUNCATE TABLE silver.silver_members_source;

    -- 3. Insert incremental records with safe TRY_TO_DATE parsing (handles '''' and invalid dates as NULL)
    INSERT INTO silver.silver_members_source (
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
    )
    SELECT
        TRIM(member_name) AS member_name,
        member_id,
        COALESCE(
            TRY_TO_DATE(NULLIF(TRIM(enrollment_date), ''''), ''YYYYMMDD''),
            TRY_TO_DATE(NULLIF(TRIM(enrollment_date), ''''), ''YYYY-MM-DD'')
        ) AS enrollment_date,
        COALESCE(
            TRY_TO_DATE(NULLIF(TRIM(last_flight_date), ''''), ''YYYYMMDD''),
            TRY_TO_DATE(NULLIF(TRIM(last_flight_date), ''''), ''YYYY-MM-DD'')
        ) AS last_flight_date,
        UPPER(NULLIF(TRIM(tier_code), '''')) AS tier_code,
        NULLIF(TRIM(agent_name), '''') AS agent_name,
        COALESCE(
            TRY_TO_DATE(LPAD(NULLIF(TRIM(dob), ''''), 8, ''0''), ''DDMMYYYY''),
            TRY_TO_DATE(NULLIF(TRIM(dob), ''''), ''YYYY-MM-DD'')
        ) AS dob,
        UPPER(NULLIF(TRIM(is_active), '''')) AS is_active,
        CASE
            WHEN country IS NULL
              OR TRIM(country) = ''''
              OR UPPER(TRIM(country)) IN (''NULL'', ''NONE'', ''__HIVE_DEFAULT_PARTITION__'')
            THEN ''UNKNOWN''
            ELSE UPPER(TRIM(country))
        END AS country,
        CASE
            WHEN state IS NULL
              OR TRIM(state) = ''''
              OR UPPER(TRIM(state)) IN (''NULL'', ''NONE'', ''UNKNOWN'', ''__HIVE_DEFAULT_PARTITION__'')
            THEN NULL
            ELSE UPPER(TRIM(state))
        END AS state,
        load_timestamp
    FROM bronze.members_clean
    WHERE load_timestamp > :members_watermark;

    members_inserted := SQLROWCOUNT;

    -- 4. Update watermark in ingestion_control if new rows were inserted
    IF (members_inserted > 0) THEN
        UPDATE ingestion_control
           SET last_load_timestamp = (SELECT MAX(load_timestamp) FROM silver.silver_members_source),
               last_run_status     = ''SUCCESS''
         WHERE UPPER(TRIM(table_name)) = ''MEMBERS_CLEAN'';
    END IF;

    RETURN ''silver_members_source loaded incrementally. Rows inserted: '' || members_inserted;
END;
';