CREATE OR REPLACE PROCEDURE SKYPOINTS.SILVER.SP_MERGE_SILVER_REDEMPTIONS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    rows_affected INT;
BEGIN
    MERGE INTO silver.silver_redemptions AS target
    USING (
        SELECT
            TRIM(txn_id) AS txn_id,
            TRY_TO_NUMBER(TRIM(member_id))::INT AS member_id,
            txn_date,
            TRIM(partner) AS partner,
            miles_redeemed,
            UPPER(TRIM(status)) AS status,
            feed_date,
            load_timestamp
        FROM silver.silver_redemptions_source
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY TRIM(txn_id)
            ORDER BY feed_date DESC NULLS LAST, load_timestamp DESC NULLS LAST
        ) = 1
    ) AS src
    ON target.txn_id = src.txn_id

    -- Update status / miles / feed_date if transaction status changes (e.g., PENDING -> COMPLETED or CANCELLED)
    WHEN MATCHED AND (
        COALESCE(src.feed_date, src.txn_date) >= COALESCE(target.feed_date, target.txn_date)
        AND (
            target.status <> src.status
            OR target.miles_redeemed <> src.miles_redeemed
            OR target.partner <> src.partner
        )
    ) THEN UPDATE SET
        target.member_id      = src.member_id,
        target.txn_date       = src.txn_date,
        target.partner        = src.partner,
        target.miles_redeemed = src.miles_redeemed,
        target.status         = src.status,
        target.feed_date      = COALESCE(src.feed_date, target.feed_date),
        target.updated_at     = CURRENT_TIMESTAMP()::TIMESTAMP_NTZ

    -- Insert new redemption transactions
    WHEN NOT MATCHED THEN INSERT (
        txn_id,
        member_id,
        txn_date,
        partner,
        miles_redeemed,
        status,
        feed_date,
        created_at,
        updated_at
    ) VALUES (
        src.txn_id,
        src.member_id,
        src.txn_date,
        src.partner,
        src.miles_redeemed,
        src.status,
        src.feed_date,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
    );

    rows_affected := SQLROWCOUNT;

    RETURN ''silver.silver_redemptions merge complete. Rows inserted/updated: '' || rows_affected;
END;
';