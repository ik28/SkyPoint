CREATE OR REPLACE PROCEDURE SKYPOINTS.SILVER.SP_LOAD_SILVER_REDEMPTIONS_SOURCE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    redemptions_watermark TIMESTAMP_NTZ;
    redemptions_inserted  INT;
BEGIN
    -- 1. Fetch last_load_timestamp watermark from ingestion_control
    SELECT COALESCE(MAX(last_load_timestamp), ''1900-01-01 00:00:00''::TIMESTAMP_NTZ)
      INTO :redemptions_watermark
      FROM ingestion_control
     WHERE UPPER(TRIM(table_name)) = ''REDEMPTIONS_CLEAN'';

    -- 2. Truncate silver_redemptions_source
    TRUNCATE TABLE silver.silver_redemptions_source;

    -- 3. Insert incremental records from bronze.redemptions_clean
    INSERT INTO silver.silver_redemptions_source (
        member_id,
        txn_id,
        txn_date,
        partner,
        miles_redeemed,
        status,
        feed_date,
        load_timestamp
    )
    SELECT
        member_id,
        txn_id,
        txn_date,
        partner,
        miles_redeemed,
        status,
        feed_date,
        load_timestamp
    FROM bronze.redemptions_clean
    WHERE load_timestamp > :redemptions_watermark;

    redemptions_inserted := SQLROWCOUNT;

    -- 4. Update watermark in ingestion_control if new rows were inserted
    IF (redemptions_inserted > 0) THEN
        UPDATE ingestion_control
           SET last_load_timestamp = (SELECT MAX(load_timestamp) FROM silver.silver_redemptions_source),
               last_run_status     = ''SUCCESS''
         WHERE UPPER(TRIM(table_name)) = ''REDEMPTIONS_CLEAN'';
    END IF;

    RETURN ''silver_redemptions_source loaded incrementally. Rows inserted: '' || redemptions_inserted;
END;
';