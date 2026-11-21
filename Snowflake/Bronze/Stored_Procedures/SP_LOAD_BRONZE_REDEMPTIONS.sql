CREATE OR REPLACE PROCEDURE SKYPOINTS.BRONZE.SP_LOAD_BRONZE_REDEMPTIONS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
BEGIN
    -- 1. Load redemptions_clean (extracts feed_date from S3 folder path + load_timestamp)
    COPY INTO bronze.redemptions_clean (
        member_id,
        txn_id,
        txn_date,
        partner,
        miles_redeemed,
        status,
        feed_date,
        load_timestamp
    )
    FROM (
        SELECT
            $1:member_id::VARCHAR,
            $1:txn_id::VARCHAR,
            $1:txn_date::VARCHAR,
            $1:partner::VARCHAR,
            $1:miles_redeemed::INT,
            $1:status::VARCHAR,
            REGEXP_SUBSTR(METADATA$FILENAME, ''feed_date=([^/]+)'', 1, 1, ''e'', 1)::VARCHAR,
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
        FROM @stg_skypoints_redemptions_clean
    )
    FILE_FORMAT = (TYPE = ''PARQUET'')
    PATTERN = ''.*\\.parquet'';

    -- 2. Load redemptions_bad_records (maps _corrupt_record, feed_date + load_timestamp)
    COPY INTO bronze.redemptions_bad_records (
        member_id,
        txn_id,
        txn_date,
        partner,
        miles_redeemed,
        status,
        corrupt_record,
        feed_date,
        load_timestamp
    )
    FROM (
        SELECT
            $1:member_id::VARCHAR,
            $1:txn_id::VARCHAR,
            $1:txn_date::VARCHAR,
            $1:partner::VARCHAR,
            $1:miles_redeemed::INT,
            $1:status::VARCHAR,
            $1:_corrupt_record::VARCHAR,
            REGEXP_SUBSTR(METADATA$FILENAME, ''feed_date=([^/]+)'', 1, 1, ''e'', 1)::VARCHAR,
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
        FROM @stg_skypoint_redemption_bad
    )
    FILE_FORMAT = (TYPE = ''PARQUET'')
    PATTERN = ''.*\\.parquet'';

    RETURN ''Bronze Redemptions load complete (redemptions_clean and redemptions_bad_records).'';
END;
';