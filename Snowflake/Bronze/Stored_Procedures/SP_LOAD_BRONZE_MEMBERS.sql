CREATE OR REPLACE PROCEDURE SKYPOINTS.BRONZE.SP_LOAD_BRONZE_MEMBERS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
BEGIN
    -- 1. Load members_clean (extracts country & state from S3 folder path + load_timestamp)
    COPY INTO bronze.members_clean (
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
    FROM (
        SELECT
            $1:member_name::VARCHAR,
            $1:member_id::INT,
            $1:enrollment_date::VARCHAR,
            $1:last_flight_date::VARCHAR,
            $1:tier_code::VARCHAR,
            $1:agent_name::VARCHAR,
            $1:dob::VARCHAR,
            $1:is_active::VARCHAR,
            REGEXP_SUBSTR(METADATA$FILENAME, ''country=([^/]+)'', 1, 1, ''e'', 1)::VARCHAR,
            REGEXP_SUBSTR(METADATA$FILENAME, ''state=([^/]+)'', 1, 1, ''e'', 1)::VARCHAR,
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
        FROM @stg_skypoint_members_clean
    )
    FILE_FORMAT = (TYPE = ''PARQUET'')
    PATTERN = ''.*\\.parquet'';

    -- 2. Load members_bad_records (explicitly maps columns + load_timestamp)
    COPY INTO bronze.members_bad_records (
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
        load_timestamp
    )
    FROM (
        SELECT
            $1:member_name::VARCHAR,
            $1:member_id::VARCHAR,
            $1:enrollment_date::VARCHAR,
            $1:last_flight_date::VARCHAR,
            $1:tier_code::VARCHAR,
            $1:agent_name::VARCHAR,
            $1:state::VARCHAR,
            $1:country::VARCHAR,
            $1:dob::VARCHAR,
            $1:is_active::VARCHAR,
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
        FROM @stg_skypoints_members_bad
    )
    FILE_FORMAT = (TYPE = ''PARQUET'')
    PATTERN = ''.*\\.parquet'';

    RETURN ''Bronze Members load complete (members_clean and members_bad_records).'';
END;
';