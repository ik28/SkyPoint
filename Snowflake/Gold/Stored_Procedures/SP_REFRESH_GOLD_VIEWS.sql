CREATE OR REPLACE PROCEDURE SKYPOINTS.GOLD.SP_REFRESH_GOLD_VIEWS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
BEGIN
    CREATE OR REPLACE VIEW silver.vw_silver_members AS
    SELECT
        member_id,
        member_name,
        enrollment_date,
        last_flight_date,
        tier_code,
        agent_name,
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
        is_active,
        country,
        state,
        created_at,
        updated_at
    FROM silver.silver_members;

    CREATE OR REPLACE VIEW gold.vw_member_horizon_summary AS
    SELECT
        m.member_id,
        m.member_name,
        m.country,
        m.state,
        m.tier_code,
        m.age,
        m.stale_member,
        m.is_active,
        m.enrollment_date,
        m.last_flight_date,
        DATEDIFF(''day'', m.last_flight_date, CURRENT_DATE()) AS days_since_last_flight,
        IFF(m.last_flight_date >= DATEADD(''day'', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
        IFF(m.last_flight_date >= DATEADD(''day'', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
        IFF(m.last_flight_date >= DATEADD(''year'', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
        IFF(m.last_flight_date >= DATEADD(''year'', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
        COUNT(IFF(r.txn_date >= DATEADD(''day'', -30, CURRENT_DATE()), r.txn_id, NULL)) AS txns_30d,
        COUNT(IFF(r.txn_date >= DATEADD(''day'', -30, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.txn_id, NULL)) AS completed_txns_30d,
        COALESCE(SUM(IFF(r.txn_date >= DATEADD(''day'', -30, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.miles_redeemed, 0)), 0) AS completed_miles_30d,
        COUNT(DISTINCT IFF(r.txn_date >= DATEADD(''day'', -30, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.partner, NULL)) AS active_partners_30d,
        COUNT(IFF(r.txn_date >= DATEADD(''day'', -90, CURRENT_DATE()), r.txn_id, NULL)) AS txns_90d,
        COUNT(IFF(r.txn_date >= DATEADD(''day'', -90, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.txn_id, NULL)) AS completed_txns_90d,
        COALESCE(SUM(IFF(r.txn_date >= DATEADD(''day'', -90, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.miles_redeemed, 0)), 0) AS completed_miles_90d,
        COUNT(DISTINCT IFF(r.txn_date >= DATEADD(''day'', -90, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.partner, NULL)) AS active_partners_90d,
        COUNT(IFF(r.txn_date >= DATEADD(''year'', -1, CURRENT_DATE()), r.txn_id, NULL)) AS txns_1y,
        COUNT(IFF(r.txn_date >= DATEADD(''year'', -1, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.txn_id, NULL)) AS completed_txns_1y,
        COALESCE(SUM(IFF(r.txn_date >= DATEADD(''year'', -1, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.miles_redeemed, 0)), 0) AS completed_miles_1y,
        COUNT(DISTINCT IFF(r.txn_date >= DATEADD(''year'', -1, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.partner, NULL)) AS active_partners_1y,
        COUNT(IFF(r.txn_date >= DATEADD(''year'', -5, CURRENT_DATE()), r.txn_id, NULL)) AS txns_5y,
        COUNT(IFF(r.txn_date >= DATEADD(''year'', -5, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.txn_id, NULL)) AS completed_txns_5y,
        COALESCE(SUM(IFF(r.txn_date >= DATEADD(''year'', -5, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.miles_redeemed, 0)), 0) AS completed_miles_5y,
        COUNT(DISTINCT IFF(r.txn_date >= DATEADD(''year'', -5, CURRENT_DATE()) AND r.status = ''COMPLETED'', r.partner, NULL)) AS active_partners_5y,
        COUNT(r.txn_id) AS lifetime_txns,
        COALESCE(SUM(IFF(r.status = ''COMPLETED'', r.miles_redeemed, 0)), 0) AS lifetime_completed_miles,
        COALESCE(SUM(IFF(r.status = ''PENDING'', r.miles_redeemed, 0)), 0) AS lifetime_pending_miles,
        COALESCE(SUM(IFF(r.status = ''CANCELLED'', r.miles_redeemed, 0)), 0) AS lifetime_cancelled_miles,
        MAX(r.txn_date) AS last_redemption_date,
        CASE
            WHEN m.last_flight_date >= DATEADD(''day'', -30, CURRENT_DATE())
              OR MAX(r.txn_date) >= DATEADD(''day'', -30, CURRENT_DATE()) THEN ''HIGHLY_ACTIVE_30D''
            WHEN m.last_flight_date >= DATEADD(''day'', -90, CURRENT_DATE())
              OR MAX(r.txn_date) >= DATEADD(''day'', -90, CURRENT_DATE()) THEN ''ACTIVE_90D''
            WHEN m.last_flight_date >= DATEADD(''year'', -1, CURRENT_DATE())
              OR MAX(r.txn_date) >= DATEADD(''year'', -1, CURRENT_DATE()) THEN ''COOLING_1Y''
            ELSE ''DORMANT_OVER_1Y''
        END AS engagement_segment
    FROM silver.vw_silver_members AS m
    LEFT JOIN silver.silver_redemptions AS r
        ON m.member_id = r.member_id
    GROUP BY
        m.member_id, m.member_name, m.country, m.state, m.tier_code,
        m.age, m.stale_member, m.is_active, m.enrollment_date, m.last_flight_date;

    CREATE OR REPLACE VIEW gold.vw_country_wise_analysis AS
    SELECT
        country,
        COUNT(member_id) AS total_members,
        COUNT(IFF(is_active = ''A'', member_id, NULL)) AS active_flag_members,
        COUNT(IFF(stale_member = TRUE, member_id, NULL)) AS stale_members_gt_90d,
        ROUND(100.0 * COUNT(IFF(stale_member = TRUE, member_id, NULL)) / NULLIF(COUNT(member_id), 0), 2) AS stale_member_pct,
        ROUND(AVG(age), 1) AS avg_member_age,
        COUNT(IFF(tier_code = ''PLT'', member_id, NULL)) AS platinum_members,
        COUNT(IFF(tier_code = ''GLD'', member_id, NULL)) AS gold_members,
        COUNT(IFF(tier_code = ''SLV'', member_id, NULL)) AS silver_members,
        COUNT(IFF(engagement_segment = ''HIGHLY_ACTIVE_30D'', member_id, NULL)) AS highly_active_30d_members,
        COUNT(IFF(engagement_segment = ''ACTIVE_90D'', member_id, NULL)) AS active_90d_members,
        COUNT(IFF(engagement_segment = ''COOLING_1Y'', member_id, NULL)) AS cooling_1y_members,
        COUNT(IFF(engagement_segment = ''DORMANT_OVER_1Y'', member_id, NULL)) AS dormant_over_1y_members,
        COUNT(IFF(lifetime_txns > 0, member_id, NULL)) AS members_who_redeemed,
        ROUND(100.0 * COUNT(IFF(lifetime_txns > 0, member_id, NULL)) / NULLIF(COUNT(member_id), 0), 2) AS redemption_penetration_pct,
        SUM(lifetime_txns) AS total_redemption_txns,
        SUM(lifetime_completed_miles) AS total_completed_miles,
        SUM(lifetime_pending_miles) AS total_pending_miles,
        ROUND(SUM(lifetime_completed_miles) / NULLIF(COUNT(member_id), 0), 2) AS avg_completed_miles_per_member
    FROM gold.vw_member_horizon_summary
    GROUP BY country;

    CREATE OR REPLACE VIEW gold.vw_country_horizon_analysis AS
    SELECT
        country,
        COUNT(member_id) AS total_members,
        COUNT(IFF(flew_last_30d, member_id, NULL)) AS flyers_30d,
        COUNT(IFF(completed_txns_30d > 0, member_id, NULL)) AS redeemers_30d,
        SUM(completed_txns_30d) AS completed_txns_30d,
        SUM(completed_miles_30d) AS completed_miles_30d,
        COUNT(IFF(flew_last_90d, member_id, NULL)) AS flyers_90d,
        COUNT(IFF(completed_txns_90d > 0, member_id, NULL)) AS redeemers_90d,
        SUM(completed_txns_90d) AS completed_txns_90d,
        SUM(completed_miles_90d) AS completed_miles_90d,
        COUNT(IFF(flew_last_1y, member_id, NULL)) AS flyers_1y,
        COUNT(IFF(completed_txns_1y > 0, member_id, NULL)) AS redeemers_1y,
        SUM(completed_txns_1y) AS completed_txns_1y,
        SUM(completed_miles_1y) AS completed_miles_1y,
        COUNT(IFF(flew_last_5y, member_id, NULL)) AS flyers_5y,
        COUNT(IFF(completed_txns_5y > 0, member_id, NULL)) AS redeemers_5y,
        SUM(completed_txns_5y) AS completed_txns_5y,
        SUM(completed_miles_5y) AS completed_miles_5y
    FROM gold.vw_member_horizon_summary
    GROUP BY country;

    CALL gold.sp_create_country_horizon_views();

    RETURN ''Stage 5 Complete: All Gold analytical and per-country horizon views refreshed.'';
END;
';