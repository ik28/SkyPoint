create or replace view SKYPOINTS.GOLD.VW_COUNTRY_HORIZON_ANALYSIS(
	COUNTRY,
	TOTAL_MEMBERS,
	FLYERS_30D,
	REDEEMERS_30D,
	COMPLETED_TXNS_30D,
	COMPLETED_MILES_30D,
	FLYERS_90D,
	REDEEMERS_90D,
	COMPLETED_TXNS_90D,
	COMPLETED_MILES_90D,
	FLYERS_1Y,
	REDEEMERS_1Y,
	COMPLETED_TXNS_1Y,
	COMPLETED_MILES_1Y,
	FLYERS_5Y,
	REDEEMERS_5Y,
	COMPLETED_TXNS_5Y,
	COMPLETED_MILES_5Y
) as
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


    create or replace view SKYPOINTS.GOLD.VW_COUNTRY_WISE_ANALYSIS(
	COUNTRY,
	TOTAL_MEMBERS,
	ACTIVE_FLAG_MEMBERS,
	STALE_MEMBERS_GT_90D,
	STALE_MEMBER_PCT,
	AVG_MEMBER_AGE,
	PLATINUM_MEMBERS,
	GOLD_MEMBERS,
	SILVER_MEMBERS,
	HIGHLY_ACTIVE_30D_MEMBERS,
	ACTIVE_90D_MEMBERS,
	COOLING_1Y_MEMBERS,
	DORMANT_OVER_1Y_MEMBERS,
	MEMBERS_WHO_REDEEMED,
	REDEMPTION_PENETRATION_PCT,
	TOTAL_REDEMPTION_TXNS,
	TOTAL_COMPLETED_MILES,
	TOTAL_PENDING_MILES,
	AVG_COMPLETED_MILES_PER_MEMBER
) as
    SELECT
        country,
        COUNT(member_id) AS total_members,
        COUNT(IFF(is_active = 'A', member_id, NULL)) AS active_flag_members,
        COUNT(IFF(stale_member = TRUE, member_id, NULL)) AS stale_members_gt_90d,
        ROUND(100.0 * COUNT(IFF(stale_member = TRUE, member_id, NULL)) / NULLIF(COUNT(member_id), 0), 2) AS stale_member_pct,
        ROUND(AVG(age), 1) AS avg_member_age,
        COUNT(IFF(tier_code = 'PLT', member_id, NULL)) AS platinum_members,
        COUNT(IFF(tier_code = 'GLD', member_id, NULL)) AS gold_members,
        COUNT(IFF(tier_code = 'SLV', member_id, NULL)) AS silver_members,
        COUNT(IFF(engagement_segment = 'HIGHLY_ACTIVE_30D', member_id, NULL)) AS highly_active_30d_members,
        COUNT(IFF(engagement_segment = 'ACTIVE_90D', member_id, NULL)) AS active_90d_members,
        COUNT(IFF(engagement_segment = 'COOLING_1Y', member_id, NULL)) AS cooling_1y_members,
        COUNT(IFF(engagement_segment = 'DORMANT_OVER_1Y', member_id, NULL)) AS dormant_over_1y_members,
        COUNT(IFF(lifetime_txns > 0, member_id, NULL)) AS members_who_redeemed,
        ROUND(100.0 * COUNT(IFF(lifetime_txns > 0, member_id, NULL)) / NULLIF(COUNT(member_id), 0), 2) AS redemption_penetration_pct,
        SUM(lifetime_txns) AS total_redemption_txns,
        SUM(lifetime_completed_miles) AS total_completed_miles,
        SUM(lifetime_pending_miles) AS total_pending_miles,
        ROUND(SUM(lifetime_completed_miles) / NULLIF(COUNT(member_id), 0), 2) AS avg_completed_miles_per_member
    FROM gold.vw_member_horizon_summary
    GROUP BY country;

    create or replace view SKYPOINTS.GOLD.VW_MEMBER_HORIZON_SUMMARY(
	MEMBER_ID,
	MEMBER_NAME,
	COUNTRY,
	STATE,
	TIER_CODE,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	DAYS_SINCE_LAST_FLIGHT,
	FLEW_LAST_30D,
	FLEW_LAST_90D,
	FLEW_LAST_1Y,
	FLEW_LAST_5Y,
	TXNS_30D,
	COMPLETED_TXNS_30D,
	COMPLETED_MILES_30D,
	ACTIVE_PARTNERS_30D,
	TXNS_90D,
	COMPLETED_TXNS_90D,
	COMPLETED_MILES_90D,
	ACTIVE_PARTNERS_90D,
	TXNS_1Y,
	COMPLETED_TXNS_1Y,
	COMPLETED_MILES_1Y,
	ACTIVE_PARTNERS_1Y,
	TXNS_5Y,
	COMPLETED_TXNS_5Y,
	COMPLETED_MILES_5Y,
	ACTIVE_PARTNERS_5Y,
	LIFETIME_TXNS,
	LIFETIME_COMPLETED_MILES,
	LIFETIME_PENDING_MILES,
	LIFETIME_CANCELLED_MILES,
	LAST_REDEMPTION_DATE,
	ENGAGEMENT_SEGMENT
) as
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
        DATEDIFF('day', m.last_flight_date, CURRENT_DATE()) AS days_since_last_flight,
        IFF(m.last_flight_date >= DATEADD('day', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
        IFF(m.last_flight_date >= DATEADD('day', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
        IFF(m.last_flight_date >= DATEADD('year', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
        IFF(m.last_flight_date >= DATEADD('year', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
        COUNT(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()), r.txn_id, NULL)) AS txns_30d,
        COUNT(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_30d,
        COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_30d,
        COUNT(DISTINCT IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.partner, NULL)) AS active_partners_30d,
        COUNT(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()), r.txn_id, NULL)) AS txns_90d,
        COUNT(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_90d,
        COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_90d,
        COUNT(DISTINCT IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.partner, NULL)) AS active_partners_90d,
        COUNT(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()), r.txn_id, NULL)) AS txns_1y,
        COUNT(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_1y,
        COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_1y,
        COUNT(DISTINCT IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.partner, NULL)) AS active_partners_1y,
        COUNT(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()), r.txn_id, NULL)) AS txns_5y,
        COUNT(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_5y,
        COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_5y,
        COUNT(DISTINCT IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.partner, NULL)) AS active_partners_5y,
        COUNT(r.txn_id) AS lifetime_txns,
        COALESCE(SUM(IFF(r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS lifetime_completed_miles,
        COALESCE(SUM(IFF(r.status = 'PENDING', r.miles_redeemed, 0)), 0) AS lifetime_pending_miles,
        COALESCE(SUM(IFF(r.status = 'CANCELLED', r.miles_redeemed, 0)), 0) AS lifetime_cancelled_miles,
        MAX(r.txn_date) AS last_redemption_date,
        CASE
            WHEN m.last_flight_date >= DATEADD('day', -30, CURRENT_DATE())
              OR MAX(r.txn_date) >= DATEADD('day', -30, CURRENT_DATE()) THEN 'HIGHLY_ACTIVE_30D'
            WHEN m.last_flight_date >= DATEADD('day', -90, CURRENT_DATE())
              OR MAX(r.txn_date) >= DATEADD('day', -90, CURRENT_DATE()) THEN 'ACTIVE_90D'
            WHEN m.last_flight_date >= DATEADD('year', -1, CURRENT_DATE())
              OR MAX(r.txn_date) >= DATEADD('year', -1, CURRENT_DATE()) THEN 'COOLING_1Y'
            ELSE 'DORMANT_OVER_1Y'
        END AS engagement_segment
    FROM silver.vw_silver_members AS m
    LEFT JOIN silver.silver_redemptions AS r
        ON m.member_id = r.member_id
    GROUP BY
        m.member_id, m.member_name, m.country, m.state, m.tier_code,
        m.age, m.stale_member, m.is_active, m.enrollment_date, m.last_flight_date;

create or replace view SKYPOINTS.GOLD.VW_MEMBER_REDEMPTION_SUMMARY(
	MEMBER_ID,
	MEMBER_NAME,
	COUNTRY,
	STATE,
	TIER_CODE,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	TOTAL_TXN_COUNT,
	COMPLETED_TXN_COUNT,
	PENDING_TXN_COUNT,
	CANCELLED_TXN_COUNT,
	TOTAL_COMPLETED_MILES,
	TOTAL_PENDING_MILES,
	LAST_REDEMPTION_DATE
) as
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
    COUNT(r.txn_id) AS total_txn_count,
    COUNT(IFF(r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txn_count,
    COUNT(IFF(r.status = 'PENDING', r.txn_id, NULL)) AS pending_txn_count,
    COUNT(IFF(r.status = 'CANCELLED', r.txn_id, NULL)) AS cancelled_txn_count,
    COALESCE(SUM(IFF(r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS total_completed_miles,
    COALESCE(SUM(IFF(r.status = 'PENDING', r.miles_redeemed, 0)), 0) AS total_pending_miles,
    MAX(r.txn_date) AS last_redemption_date
FROM silver.vw_silver_members AS m
LEFT JOIN silver.silver_redemptions AS r
    ON m.member_id = r.member_id
GROUP BY
    m.member_id,
    m.member_name,
    m.country,
    m.state,
    m.tier_code,
    m.age,
    m.stale_member,
    m.is_active,
    m.enrollment_date,
    m.last_flight_date;


create or replace view SKYPOINTS.GOLD.VW_REDEMPTIONS_ENRICHED(
	TXN_ID,
	TXN_DATE,
	FEED_DATE,
	PARTNER,
	MILES_REDEEMED,
	REDEMPTION_STATUS,
	MEMBER_ID,
	MEMBER_NAME,
	TIER_CODE,
	COUNTRY,
	STATE,
	DOB,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	DAYS_SINCE_ENROLLMENT_AT_TXN,
	IS_ORPHAN_MEMBER
) as
SELECT
    r.txn_id,
    r.txn_date,
    r.feed_date,
    r.partner,
    r.miles_redeemed,
    r.status AS redemption_status,
    r.member_id,
    m.member_name,
    m.tier_code,
    m.country,
    m.state,
    m.dob,
    m.age,
    m.stale_member,
    m.is_active,
    m.enrollment_date,
    m.last_flight_date,
    DATEDIFF('day', m.enrollment_date, r.txn_date) AS days_since_enrollment_at_txn,
    IFF(m.member_id IS NULL, TRUE, FALSE) AS is_orphan_member
FROM silver.silver_redemptions AS r
LEFT JOIN silver.vw_silver_members AS m
    ON r.member_id = m.member_id;

create or replace view SKYPOINTS.GOLD.VW_TABLE_AU_HORIZON_SUMMARY(
	MEMBER_ID,
	MEMBER_NAME,
	COUNTRY,
	STATE,
	TIER_CODE,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	FLEW_LAST_30D,
	COMPLETED_TXNS_30D,
	COMPLETED_MILES_30D,
	FLEW_LAST_90D,
	COMPLETED_TXNS_90D,
	COMPLETED_MILES_90D,
	FLEW_LAST_1Y,
	COMPLETED_TXNS_1Y,
	COMPLETED_MILES_1Y,
	FLEW_LAST_5Y,
	COMPLETED_TXNS_5Y,
	COMPLETED_MILES_5Y
) as
            SELECT
                m.member_id,
                m.member_name,
                m.country,
                m.state,
                m.tier_code,
                IFF(m.dob IS NOT NULL,
                    DATEDIFF('year', m.dob, CURRENT_DATE())
                    - IFF(TO_CHAR(CURRENT_DATE(), 'MMDD') < TO_CHAR(m.dob, 'MMDD'), 1, 0),
                    NULL) AS age,
                IFF(m.last_flight_date IS NOT NULL AND DATEDIFF('day', m.last_flight_date, CURRENT_DATE()) > 90, TRUE, FALSE) AS stale_member,
                m.is_active,
                m.enrollment_date,
                m.last_flight_date,

                -- 30-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_30d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_30d,

                -- 90-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_90d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_90d,

                -- 1-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_1y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_1y,

                -- 5-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_5y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_5y
            FROM gold.table_AU AS m
            LEFT JOIN silver.silver_redemptions AS r
                ON m.member_id = r.member_id
            GROUP BY
                m.member_id, m.member_name, m.country, m.state, m.tier_code,
                m.dob, m.is_active, m.enrollment_date, m.last_flight_date;

create or replace view SKYPOINTS.GOLD.VW_TABLE_CAN_HORIZON_SUMMARY(
	MEMBER_ID,
	MEMBER_NAME,
	COUNTRY,
	STATE,
	TIER_CODE,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	FLEW_LAST_30D,
	COMPLETED_TXNS_30D,
	COMPLETED_MILES_30D,
	FLEW_LAST_90D,
	COMPLETED_TXNS_90D,
	COMPLETED_MILES_90D,
	FLEW_LAST_1Y,
	COMPLETED_TXNS_1Y,
	COMPLETED_MILES_1Y,
	FLEW_LAST_5Y,
	COMPLETED_TXNS_5Y,
	COMPLETED_MILES_5Y
) as
            SELECT
                m.member_id,
                m.member_name,
                m.country,
                m.state,
                m.tier_code,
                IFF(m.dob IS NOT NULL,
                    DATEDIFF('year', m.dob, CURRENT_DATE())
                    - IFF(TO_CHAR(CURRENT_DATE(), 'MMDD') < TO_CHAR(m.dob, 'MMDD'), 1, 0),
                    NULL) AS age,
                IFF(m.last_flight_date IS NOT NULL AND DATEDIFF('day', m.last_flight_date, CURRENT_DATE()) > 90, TRUE, FALSE) AS stale_member,
                m.is_active,
                m.enrollment_date,
                m.last_flight_date,

                -- 30-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_30d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_30d,

                -- 90-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_90d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_90d,

                -- 1-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_1y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_1y,

                -- 5-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_5y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_5y
            FROM gold.table_CAN AS m
            LEFT JOIN silver.silver_redemptions AS r
                ON m.member_id = r.member_id
            GROUP BY
                m.member_id, m.member_name, m.country, m.state, m.tier_code,
                m.dob, m.is_active, m.enrollment_date, m.last_flight_date;


create or replace view SKYPOINTS.GOLD.VW_TABLE_IND_HORIZON_SUMMARY(
	MEMBER_ID,
	MEMBER_NAME,
	COUNTRY,
	STATE,
	TIER_CODE,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	FLEW_LAST_30D,
	COMPLETED_TXNS_30D,
	COMPLETED_MILES_30D,
	FLEW_LAST_90D,
	COMPLETED_TXNS_90D,
	COMPLETED_MILES_90D,
	FLEW_LAST_1Y,
	COMPLETED_TXNS_1Y,
	COMPLETED_MILES_1Y,
	FLEW_LAST_5Y,
	COMPLETED_TXNS_5Y,
	COMPLETED_MILES_5Y
) as
            SELECT
                m.member_id,
                m.member_name,
                m.country,
                m.state,
                m.tier_code,
                IFF(m.dob IS NOT NULL,
                    DATEDIFF('year', m.dob, CURRENT_DATE())
                    - IFF(TO_CHAR(CURRENT_DATE(), 'MMDD') < TO_CHAR(m.dob, 'MMDD'), 1, 0),
                    NULL) AS age,
                IFF(m.last_flight_date IS NOT NULL AND DATEDIFF('day', m.last_flight_date, CURRENT_DATE()) > 90, TRUE, FALSE) AS stale_member,
                m.is_active,
                m.enrollment_date,
                m.last_flight_date,

                -- 30-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_30d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_30d,

                -- 90-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_90d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_90d,

                -- 1-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_1y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_1y,

                -- 5-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_5y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_5y
            FROM gold.table_IND AS m
            LEFT JOIN silver.silver_redemptions AS r
                ON m.member_id = r.member_id
            GROUP BY
                m.member_id, m.member_name, m.country, m.state, m.tier_code,
                m.dob, m.is_active, m.enrollment_date, m.last_flight_date;


create or replace view SKYPOINTS.GOLD.VW_TABLE_PHIL_HORIZON_SUMMARY(
	MEMBER_ID,
	MEMBER_NAME,
	COUNTRY,
	STATE,
	TIER_CODE,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	FLEW_LAST_30D,
	COMPLETED_TXNS_30D,
	COMPLETED_MILES_30D,
	FLEW_LAST_90D,
	COMPLETED_TXNS_90D,
	COMPLETED_MILES_90D,
	FLEW_LAST_1Y,
	COMPLETED_TXNS_1Y,
	COMPLETED_MILES_1Y,
	FLEW_LAST_5Y,
	COMPLETED_TXNS_5Y,
	COMPLETED_MILES_5Y
) as
            SELECT
                m.member_id,
                m.member_name,
                m.country,
                m.state,
                m.tier_code,
                IFF(m.dob IS NOT NULL,
                    DATEDIFF('year', m.dob, CURRENT_DATE())
                    - IFF(TO_CHAR(CURRENT_DATE(), 'MMDD') < TO_CHAR(m.dob, 'MMDD'), 1, 0),
                    NULL) AS age,
                IFF(m.last_flight_date IS NOT NULL AND DATEDIFF('day', m.last_flight_date, CURRENT_DATE()) > 90, TRUE, FALSE) AS stale_member,
                m.is_active,
                m.enrollment_date,
                m.last_flight_date,

                -- 30-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_30d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_30d,

                -- 90-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_90d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_90d,

                -- 1-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_1y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_1y,

                -- 5-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_5y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_5y
            FROM gold.table_PHIL AS m
            LEFT JOIN silver.silver_redemptions AS r
                ON m.member_id = r.member_id
            GROUP BY
                m.member_id, m.member_name, m.country, m.state, m.tier_code,
                m.dob, m.is_active, m.enrollment_date, m.last_flight_date;


create or replace view SKYPOINTS.GOLD.VW_TABLE_UK_HORIZON_SUMMARY(
	MEMBER_ID,
	MEMBER_NAME,
	COUNTRY,
	STATE,
	TIER_CODE,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	FLEW_LAST_30D,
	COMPLETED_TXNS_30D,
	COMPLETED_MILES_30D,
	FLEW_LAST_90D,
	COMPLETED_TXNS_90D,
	COMPLETED_MILES_90D,
	FLEW_LAST_1Y,
	COMPLETED_TXNS_1Y,
	COMPLETED_MILES_1Y,
	FLEW_LAST_5Y,
	COMPLETED_TXNS_5Y,
	COMPLETED_MILES_5Y
) as
            SELECT
                m.member_id,
                m.member_name,
                m.country,
                m.state,
                m.tier_code,
                IFF(m.dob IS NOT NULL,
                    DATEDIFF('year', m.dob, CURRENT_DATE())
                    - IFF(TO_CHAR(CURRENT_DATE(), 'MMDD') < TO_CHAR(m.dob, 'MMDD'), 1, 0),
                    NULL) AS age,
                IFF(m.last_flight_date IS NOT NULL AND DATEDIFF('day', m.last_flight_date, CURRENT_DATE()) > 90, TRUE, FALSE) AS stale_member,
                m.is_active,
                m.enrollment_date,
                m.last_flight_date,

                -- 30-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_30d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_30d,

                -- 90-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_90d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_90d,

                -- 1-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_1y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_1y,

                -- 5-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_5y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_5y
            FROM gold.table_UK AS m
            LEFT JOIN silver.silver_redemptions AS r
                ON m.member_id = r.member_id
            GROUP BY
                m.member_id, m.member_name, m.country, m.state, m.tier_code,
                m.dob, m.is_active, m.enrollment_date, m.last_flight_date;


create or replace view SKYPOINTS.GOLD.VW_TABLE_USA_HORIZON_SUMMARY(
	MEMBER_ID,
	MEMBER_NAME,
	COUNTRY,
	STATE,
	TIER_CODE,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	FLEW_LAST_30D,
	COMPLETED_TXNS_30D,
	COMPLETED_MILES_30D,
	FLEW_LAST_90D,
	COMPLETED_TXNS_90D,
	COMPLETED_MILES_90D,
	FLEW_LAST_1Y,
	COMPLETED_TXNS_1Y,
	COMPLETED_MILES_1Y,
	FLEW_LAST_5Y,
	COMPLETED_TXNS_5Y,
	COMPLETED_MILES_5Y
) as
            SELECT
                m.member_id,
                m.member_name,
                m.country,
                m.state,
                m.tier_code,
                IFF(m.dob IS NOT NULL,
                    DATEDIFF('year', m.dob, CURRENT_DATE())
                    - IFF(TO_CHAR(CURRENT_DATE(), 'MMDD') < TO_CHAR(m.dob, 'MMDD'), 1, 0),
                    NULL) AS age,
                IFF(m.last_flight_date IS NOT NULL AND DATEDIFF('day', m.last_flight_date, CURRENT_DATE()) > 90, TRUE, FALSE) AS stale_member,
                m.is_active,
                m.enrollment_date,
                m.last_flight_date,

                -- 30-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_30d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_30d,

                -- 90-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_90d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_90d,

                -- 1-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_1y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_1y,

                -- 5-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_5y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_5y
            FROM gold.table_USA AS m
            LEFT JOIN silver.silver_redemptions AS r
                ON m.member_id = r.member_id
            GROUP BY
                m.member_id, m.member_name, m.country, m.state, m.tier_code,
                m.dob, m.is_active, m.enrollment_date, m.last_flight_date;


create or replace view SKYPOINTS.GOLD.VW_TABLE_XX_HORIZON_SUMMARY(
	MEMBER_ID,
	MEMBER_NAME,
	COUNTRY,
	STATE,
	TIER_CODE,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	FLEW_LAST_30D,
	COMPLETED_TXNS_30D,
	COMPLETED_MILES_30D,
	FLEW_LAST_90D,
	COMPLETED_TXNS_90D,
	COMPLETED_MILES_90D,
	FLEW_LAST_1Y,
	COMPLETED_TXNS_1Y,
	COMPLETED_MILES_1Y,
	FLEW_LAST_5Y,
	COMPLETED_TXNS_5Y,
	COMPLETED_MILES_5Y
) as
            SELECT
                m.member_id,
                m.member_name,
                m.country,
                m.state,
                m.tier_code,
                IFF(m.dob IS NOT NULL,
                    DATEDIFF('year', m.dob, CURRENT_DATE())
                    - IFF(TO_CHAR(CURRENT_DATE(), 'MMDD') < TO_CHAR(m.dob, 'MMDD'), 1, 0),
                    NULL) AS age,
                IFF(m.last_flight_date IS NOT NULL AND DATEDIFF('day', m.last_flight_date, CURRENT_DATE()) > 90, TRUE, FALSE) AS stale_member,
                m.is_active,
                m.enrollment_date,
                m.last_flight_date,

                -- 30-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_30d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_30d,

                -- 90-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_90d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_90d,

                -- 1-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_1y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_1y,

                -- 5-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_5y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_5y
            FROM gold.table_XX AS m
            LEFT JOIN silver.silver_redemptions AS r
                ON m.member_id = r.member_id
            GROUP BY
                m.member_id, m.member_name, m.country, m.state, m.tier_code,
                m.dob, m.is_active, m.enrollment_date, m.last_flight_date;


create or replace view SKYPOINTS.GOLD.VW_TABLE_XX_HORIZON_SUMMARY(
	MEMBER_ID,
	MEMBER_NAME,
	COUNTRY,
	STATE,
	TIER_CODE,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	FLEW_LAST_30D,
	COMPLETED_TXNS_30D,
	COMPLETED_MILES_30D,
	FLEW_LAST_90D,
	COMPLETED_TXNS_90D,
	COMPLETED_MILES_90D,
	FLEW_LAST_1Y,
	COMPLETED_TXNS_1Y,
	COMPLETED_MILES_1Y,
	FLEW_LAST_5Y,
	COMPLETED_TXNS_5Y,
	COMPLETED_MILES_5Y
) as
            SELECT
                m.member_id,
                m.member_name,
                m.country,
                m.state,
                m.tier_code,
                IFF(m.dob IS NOT NULL,
                    DATEDIFF('year', m.dob, CURRENT_DATE())
                    - IFF(TO_CHAR(CURRENT_DATE(), 'MMDD') < TO_CHAR(m.dob, 'MMDD'), 1, 0),
                    NULL) AS age,
                IFF(m.last_flight_date IS NOT NULL AND DATEDIFF('day', m.last_flight_date, CURRENT_DATE()) > 90, TRUE, FALSE) AS stale_member,
                m.is_active,
                m.enrollment_date,
                m.last_flight_date,

                -- 30-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -30, CURRENT_DATE()), TRUE, FALSE) AS flew_last_30d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_30d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -30, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_30d,

                -- 90-Day Summary
                IFF(m.last_flight_date >= DATEADD('day', -90, CURRENT_DATE()), TRUE, FALSE) AS flew_last_90d,
                COUNT(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_90d,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('day', -90, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_90d,

                -- 1-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -1, CURRENT_DATE()), TRUE, FALSE) AS flew_last_1y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_1y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -1, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_1y,

                -- 5-Year Summary
                IFF(m.last_flight_date >= DATEADD('year', -5, CURRENT_DATE()), TRUE, FALSE) AS flew_last_5y,
                COUNT(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.txn_id, NULL)) AS completed_txns_5y,
                COALESCE(SUM(IFF(r.txn_date >= DATEADD('year', -5, CURRENT_DATE()) AND r.status = 'COMPLETED', r.miles_redeemed, 0)), 0) AS completed_miles_5y
            FROM gold.table_XX AS m
            LEFT JOIN silver.silver_redemptions AS r
                ON m.member_id = r.member_id
            GROUP BY
                m.member_id, m.member_name, m.country, m.state, m.tier_code,
                m.dob, m.is_active, m.enrollment_date, m.last_flight_date;