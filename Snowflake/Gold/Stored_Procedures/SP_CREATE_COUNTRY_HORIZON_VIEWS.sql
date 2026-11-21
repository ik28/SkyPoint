CREATE OR REPLACE PROCEDURE SKYPOINTS.GOLD.SP_CREATE_COUNTRY_HORIZON_VIEWS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    country_code VARCHAR;
    country_tbl  VARCHAR;
    horizon_view VARCHAR;
    cur          CURSOR FOR
        SELECT DISTINCT COALESCE(NULLIF(TRIM(UPPER(country)), ''''), ''UNKNOWN'') AS c_code
        FROM silver.silver_members;
BEGIN
    OPEN cur;
    FOR rec IN cur DO
        country_code := REGEXP_REPLACE(rec.c_code, ''[^A-Z0-9_]'', '''');
        country_tbl  := ''gold.table_'' || country_code;
        horizon_view := ''gold.vw_table_'' || country_code || ''_horizon_summary'';

        EXECUTE IMMEDIATE ''
            CREATE OR REPLACE VIEW '' || horizon_view || '' AS
            SELECT
                m.member_id,
                m.member_name,
                m.country,
                m.state,
                m.tier_code,
                IFF(m.dob IS NOT NULL,
                    DATEDIFF(''''year'''', m.dob, CURRENT_DATE())
                    - IFF(TO_CHAR(CURRENT_DATE(), ''''MMDD'''') < TO_CHAR(m.dob, ''''MMDD''''), 1, 0),
                    NULL) AS age,
                IFF(m.last_flight_date IS NOT NULL AND DATEDIFF(''''day'''', m.last_flight_date, CURRENT_DATE()) > 90, TRUE, FALSE) AS stale_member,
                m.is_active,
                m.enrollment_date,
                m.last_flight_date,

                -- 30-Day Summary
                IFF(m.last_flight_date >= DATEADD(''''day'''', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
                COUNT(IFF(r.txn_date >= DATEADD(''''day'''', -30, CURRENT_DATE()) AND r.status = ''''COMPLETED'''', r.txn_id, NULL)) AS completed_txns_30d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD(''''day'''', -30, CURRENT_DATE()) AND r.status = ''''COMPLETED'''', r.miles_redeemed, 0)), 0) AS completed_miles_30d,

                -- 90-Day Summary
                IFF(m.last_flight_date >= DATEADD(''''day'''', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
                COUNT(IFF(r.txn_date >= DATEADD(''''day'''', -90, CURRENT_DATE()) AND r.status = ''''COMPLETED'''', r.txn_id, NULL)) AS completed_txns_90d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD(''''day'''', -90, CURRENT_DATE()) AND r.status = ''''COMPLETED'''', r.miles_redeemed, 0)), 0) AS completed_miles_90d,

                -- 1-Year Summary
                IFF(m.last_flight_date >= DATEADD(''''year'''', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
                COUNT(IFF(r.txn_date >= DATEADD(''''year'''', -1, CURRENT_DATE()) AND r.status = ''''COMPLETED'''', r.txn_id, NULL)) AS completed_txns_1y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD(''''year'''', -1, CURRENT_DATE()) AND r.status = ''''COMPLETED'''', r.miles_redeemed, 0)), 0) AS completed_miles_1y,

                -- 5-Year Summary
                IFF(m.last_flight_date >= DATEADD(''''year'''', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
                COUNT(IFF(r.txn_date >= DATEADD(''''year'''', -5, CURRENT_DATE()) AND r.status = ''''COMPLETED'''', r.txn_id, NULL)) AS completed_txns_5y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD(''''year'''', -5, CURRENT_DATE()) AND r.status = ''''COMPLETED'''', r.miles_redeemed, 0)), 0) AS completed_miles_5y
            FROM '' || country_tbl || '' AS m
            LEFT JOIN silver.silver_redemptions AS r
                ON m.member_id = r.member_id
            GROUP BY
                m.member_id, m.member_name, m.country, m.state, m.tier_code,
                m.dob, m.is_active, m.enrollment_date, m.last_flight_date
        '';
    END FOR;
    CLOSE cur;

    RETURN ''Per-country horizon summary views created successfully.'';
END;
';