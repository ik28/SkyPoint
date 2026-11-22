CREATE OR REPLACE PROCEDURE SKYPOINTS.SILVER.SP_MERGE_SILVER_MEMBERS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    rows_affected INT;
BEGIN
    MERGE INTO silver.silver_members AS target
    USING (
        SELECT
            member_id,
            TRIM(member_name) AS member_name,
            enrollment_date,
            last_flight_date,
            UPPER(NULLIF(TRIM(tier_code), '''')) AS tier_code,
            NULLIF(TRIM(agent_name), '''') AS agent_name,
            dob,
            IFF(
                dob IS NOT NULL,
                DATEDIFF(''year'', dob, CURRENT_DATE())
                    - IFF(TO_CHAR(CURRENT_DATE(), ''MMDD'') < TO_CHAR(dob, ''MMDD''), 1, 0),
                NULL
            ) AS age,
            IFF(
                last_flight_date IS NOT NULL AND DATEDIFF(''day'', last_flight_date, CURRENT_DATE()) > 90,
                TRUE,
                FALSE
            ) AS stale_member,
            UPPER(NULLIF(TRIM(is_active), '''')) AS is_active,
            COALESCE(NULLIF(TRIM(UPPER(country)), ''''), ''UNKNOWN'') AS country,
            UPPER(NULLIF(TRIM(state), '''')) AS state,
            load_timestamp
        FROM silver.silver_members_source
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY member_id
            ORDER BY last_flight_date DESC NULLS LAST, load_timestamp DESC NULLS LAST
        ) = 1
    ) AS src
    ON target.member_id = src.member_id

    -- Update existing member only if incoming record is newer or same recency (handles country/state moves)
    WHEN MATCHED AND (
        COALESCE(src.last_flight_date, src.enrollment_date) >= COALESCE(target.last_flight_date, target.enrollment_date)
    ) THEN UPDATE SET
        target.member_name      = COALESCE(src.member_name, target.member_name),
        target.enrollment_date  = LEAST(src.enrollment_date, target.enrollment_date),
        target.last_flight_date = GREATEST(COALESCE(src.last_flight_date, target.last_flight_date), COALESCE(target.last_flight_date, src.last_flight_date)),
        target.tier_code        = COALESCE(src.tier_code, target.tier_code),
        target.agent_name       = COALESCE(src.agent_name, target.agent_name),
        target.dob              = COALESCE(src.dob, target.dob),
        target.age              = COALESCE(src.age, target.age),
        target.stale_member     = src.stale_member,
        target.is_active        = COALESCE(src.is_active, target.is_active),
        target.country          = COALESCE(src.country, target.country),
        target.state            = CASE
                                      WHEN src.country IS NOT NULL AND src.country <> COALESCE(target.country, '''') THEN src.state
                                      ELSE COALESCE(src.state, target.state)
                                  END,
        target.updated_at       = CURRENT_TIMESTAMP()::TIMESTAMP_NTZ

    -- Insert brand-new members
    WHEN NOT MATCHED THEN INSERT (
        member_id,
        member_name,
        enrollment_date,
        last_flight_date,
        tier_code,
        agent_name,
        dob,
        age,
        stale_member,
        is_active,
        country,
        state,
        created_at,
        updated_at
    ) VALUES (
        src.member_id,
        src.member_name,
        src.enrollment_date,
        src.last_flight_date,
        src.tier_code,
        src.agent_name,
        src.dob,
        src.age,
        src.stale_member,
        src.is_active,
        src.country,
        src.state,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
    );

    rows_affected := SQLROWCOUNT;

    RETURN ''silver.silver_members merge complete. Rows inserted/updated: '' || rows_affected;
END;
';