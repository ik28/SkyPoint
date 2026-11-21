CREATE OR REPLACE PROCEDURE SKYPOINTS.GOLD.SP_SYNC_COUNTRY_MEMBER_TABLES()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    country_code VARCHAR;
    target_tbl   VARCHAR;
    cur          CURSOR FOR
        SELECT DISTINCT COALESCE(NULLIF(TRIM(UPPER(country)), ''''), ''UNKNOWN'') AS c_code
        FROM silver.silver_members;
BEGIN
    OPEN cur;
    FOR rec IN cur DO
        country_code := REGEXP_REPLACE(rec.c_code, ''[^A-Z0-9_]'', '''');
        target_tbl   := ''gold.table_'' || country_code;

        -- 1. Create target country table dynamically if it doesn''t exist
        EXECUTE IMMEDIATE ''
            CREATE TABLE IF NOT EXISTS '' || target_tbl || '' (
                member_id         INT PRIMARY KEY,
                member_name       VARCHAR(255) NOT NULL,
                enrollment_date   DATE NOT NULL,
                last_flight_date  DATE,
                tier_code         VARCHAR(5),
                agent_name        VARCHAR(255),
                dob               DATE,
                age               INT,
                stale_member      BOOLEAN,
                is_active         VARCHAR(1),
                country           VARCHAR(5),
                state             VARCHAR(5),
                created_at        TIMESTAMP_NTZ,
                updated_at        TIMESTAMP_NTZ
            )
            CLUSTER BY (member_id)
        '';

        -- 2. Relocation cleanup: remove members from THIS country table if their latest country in Silver is now different
        EXECUTE IMMEDIATE ''
            DELETE FROM '' || target_tbl || '' tgt
            WHERE EXISTS (
                SELECT 1
                FROM silver.silver_members src
                WHERE src.member_id = tgt.member_id
                  AND COALESCE(NULLIF(TRIM(UPPER(src.country)), ''''''''), ''''UNKNOWN'''') <> '''''' || country_code || ''''''
            )
        '';

        -- 3. Upsert latest records for this country from Silver
        EXECUTE IMMEDIATE ''
            MERGE INTO '' || target_tbl || '' AS tgt
            USING (
                SELECT *
                FROM silver.silver_members
                WHERE COALESCE(NULLIF(TRIM(UPPER(country)), ''''''''), ''''UNKNOWN'''') = '''''' || country_code || ''''''
            ) AS src
            ON tgt.member_id = src.member_id
            WHEN MATCHED AND src.updated_at >= tgt.updated_at THEN UPDATE SET
                tgt.member_name      = src.member_name,
                tgt.enrollment_date  = src.enrollment_date,
                tgt.last_flight_date = src.last_flight_date,
                tgt.tier_code        = src.tier_code,
                tgt.agent_name       = src.agent_name,
                tgt.dob              = src.dob,
                tgt.age              = src.age,
                tgt.stale_member     = src.stale_member,
                tgt.is_active        = src.is_active,
                tgt.country          = src.country,
                tgt.state            = src.state,
                tgt.updated_at       = src.updated_at
            WHEN NOT MATCHED THEN INSERT (
                member_id, member_name, enrollment_date, last_flight_date,
                tier_code, agent_name, dob, age, stale_member,
                is_active, country, state, created_at, updated_at
            ) VALUES (
                src.member_id, src.member_name, src.enrollment_date, src.last_flight_date,
                src.tier_code, src.agent_name, src.dob, src.age, src.stale_member,
                src.is_active, src.country, src.state, src.created_at, src.updated_at
            )
        '';
    END FOR;
    CLOSE cur;

    RETURN ''Per-country member tables synced successfully.'';
END;
';