-- SkyPoints semantic view for Cortex Analyst / Cortex Agents
-- Run as ACCOUNTADMIN (or a role with CREATE SEMANTIC VIEW on SKYPOINTS.GOLD)

USE SCHEMA SKYPOINTS.GOLD;

CREATE OR REPLACE SEMANTIC VIEW SKYPOINTS.GOLD.SKYPOINTS_SV

  TABLES (
    members AS SKYPOINTS.GOLD.VW_MEMBER_HORIZON_SUMMARY
      PRIMARY KEY (member_id)
      WITH SYNONYMS = ('members', 'loyalty members', 'customers', 'travellers')
      COMMENT = 'One row per SkyPoints member: profile, tier, flight recency, redemption activity over 30d/90d/1y/5y/lifetime and engagement segment. Use for any member or country level question.',

    redemptions AS SKYPOINTS.GOLD.VW_REDEMPTIONS_ENRICHED
      PRIMARY KEY (txn_id)
      WITH SYNONYMS = ('redemptions', 'transactions', 'mileage redemptions', 'partner redemptions')
      COMMENT = 'One row per mileage redemption transaction with partner, miles and status. Use for partner, status and transaction-date questions.'
  )

  RELATIONSHIPS (
    redemptions_to_members AS redemptions (member_id) REFERENCES members
  )

  DIMENSIONS (
    -- ---------- members ----------
    members.member_id AS members.member_id
      WITH SYNONYMS = ('member number', 'member id', 'id')
      COMMENT = 'Unique member identifier',
    members.member_name AS members.member_name
      WITH SYNONYMS = ('name', 'customer name')
      COMMENT = 'Full name of the member',
    members.country AS members.country
      WITH SYNONYMS = ('country code', 'market', 'nation')
      COMMENT = 'Country code as stored: AU, CAN, IND, PHIL, UK, USA, XX',
    members.state AS members.state
      WITH SYNONYMS = ('province', 'region')
      COMMENT = 'State or province code of the member',
    members.tier_code AS members.tier_code
      WITH SYNONYMS = ('tier', 'membership tier', 'status level')
      COMMENT = 'Tier code: SLV = Silver, GLD = Gold, PLT = Platinum',
    members.tier_name AS CASE members.tier_code
                           WHEN 'PLT' THEN 'Platinum'
                           WHEN 'GLD' THEN 'Gold'
                           WHEN 'SLV' THEN 'Silver'
                           ELSE members.tier_code
                         END
      WITH SYNONYMS = ('tier label', 'tier full name')
      COMMENT = 'Readable tier name: Silver, Gold, Platinum',
    members.age AS members.age
      WITH SYNONYMS = ('member age', 'years old')
      COMMENT = 'Age of the member in years, derived from date of birth',
    members.is_active AS members.is_active
      WITH SYNONYMS = ('active flag', 'active status')
      COMMENT = 'Account flag: A = active, I = inactive. Not the same as recent flying activity.',
    members.stale_member AS members.stale_member
      WITH SYNONYMS = ('stale', 'inactive flyer', 'lapsed member')
      COMMENT = 'TRUE when the member has not flown for more than 90 days',
    members.enrollment_date AS members.enrollment_date
      WITH SYNONYMS = ('join date', 'signup date', 'enrolled on')
      COMMENT = 'Date the member enrolled in the program',
    members.last_flight_date AS members.last_flight_date
      WITH SYNONYMS = ('last flown', 'last flight')
      COMMENT = 'Date of the most recent flight',
    members.days_since_last_flight AS members.days_since_last_flight
      WITH SYNONYMS = ('recency', 'days since flying')
      COMMENT = 'Days between the last flight date and today',
    members.last_redemption_date AS members.last_redemption_date
      WITH SYNONYMS = ('last redeemed', 'last redemption')
      COMMENT = 'Date of the most recent redemption transaction (any status)',
    members.engagement_segment AS members.engagement_segment
      WITH SYNONYMS = ('segment', 'engagement level', 'engagement')
      COMMENT = 'HIGHLY_ACTIVE_30D = flew or redeemed in last 30 days; ACTIVE_90D = last 90 days; COOLING_1Y = last year; DORMANT_OVER_1Y = nothing for over a year',

    -- ---------- redemptions ----------
    redemptions.txn_id AS redemptions.txn_id
      WITH SYNONYMS = ('transaction id', 'redemption id')
      COMMENT = 'Unique redemption transaction id, starts with RX',
    redemptions.txn_date AS redemptions.txn_date
      WITH SYNONYMS = ('transaction date', 'redemption date', 'redeemed on')
      COMMENT = 'Date the redemption took place',
    redemptions.feed_date AS redemptions.feed_date
      WITH SYNONYMS = ('load date', 'feed date')
      COMMENT = 'Date of the partner feed that reported the transaction',
    redemptions.partner AS redemptions.partner
      WITH SYNONYMS = ('partner airline', 'redemption partner', 'airline partner')
      COMMENT = 'Partner where the miles were redeemed',
    redemptions.redemption_status AS redemptions.redemption_status
      WITH SYNONYMS = ('status', 'transaction status')
      COMMENT = 'COMPLETED, PENDING or CANCELLED. Only COMPLETED miles count as redeemed.',
    redemptions.is_orphan_member AS redemptions.is_orphan_member
      WITH SYNONYMS = ('orphan', 'unmatched member')
      COMMENT = 'TRUE when the transaction member id has no matching member profile'
  )

  METRICS (
    -- ---------- members: counts and shares ----------
    members.total_members AS COUNT(members.member_id)
      WITH SYNONYMS = ('member count', 'number of members', 'how many members')
      COMMENT = 'Number of members',
    members.active_members AS COUNT(CASE WHEN members.is_active = 'A' THEN members.member_id END)
      WITH SYNONYMS = ('active flag members')
      COMMENT = 'Members whose active flag is A',
    members.stale_members AS COUNT(CASE WHEN members.stale_member = TRUE THEN members.member_id END)
      WITH SYNONYMS = ('stale member count', 'lapsed members')
      COMMENT = 'Members with no flight in over 90 days',
    members.stale_member_pct AS ROUND(100.0 * COUNT(CASE WHEN members.stale_member = TRUE THEN members.member_id END) / NULLIF(COUNT(members.member_id), 0), 2)
      WITH SYNONYMS = ('stale percentage', 'percent stale')
      COMMENT = 'Share of members who are stale, in percent',
    members.avg_member_age AS ROUND(AVG(members.age), 1)
      WITH SYNONYMS = ('average age')
      COMMENT = 'Average member age in years',
    members.platinum_members AS COUNT(CASE WHEN members.tier_code = 'PLT' THEN members.member_id END)
      WITH SYNONYMS = ('platinum count', 'PLT members')
      COMMENT = 'Number of Platinum members',
    members.gold_members AS COUNT(CASE WHEN members.tier_code = 'GLD' THEN members.member_id END)
      WITH SYNONYMS = ('gold count', 'GLD members')
      COMMENT = 'Number of Gold members',
    members.silver_members AS COUNT(CASE WHEN members.tier_code = 'SLV' THEN members.member_id END)
      WITH SYNONYMS = ('silver count', 'SLV members')
      COMMENT = 'Number of Silver members',
    members.dormant_members AS COUNT(CASE WHEN members.engagement_segment = 'DORMANT_OVER_1Y' THEN members.member_id END)
      WITH SYNONYMS = ('dormant count', 'dormant over 1 year')
      COMMENT = 'Members in the DORMANT_OVER_1Y engagement segment',
    members.members_who_redeemed AS COUNT(CASE WHEN members.lifetime_txns > 0 THEN members.member_id END)
      WITH SYNONYMS = ('redeemers', 'members with redemptions')
      COMMENT = 'Members with at least one redemption of any status',
    members.redemption_penetration_pct AS ROUND(100.0 * COUNT(CASE WHEN members.lifetime_txns > 0 THEN members.member_id END) / NULLIF(COUNT(members.member_id), 0), 2)
      WITH SYNONYMS = ('redemption rate', 'penetration')
      COMMENT = 'Share of members who have ever redeemed, in percent',

    -- ---------- members: flying horizons ----------
    members.flyers_30d AS COUNT(CASE WHEN members.flew_last_30d THEN members.member_id END)
      WITH SYNONYMS = ('flyers last 30 days')
      COMMENT = 'Members who flew in the last 30 days',
    members.flyers_90d AS COUNT(CASE WHEN members.flew_last_90d THEN members.member_id END)
      WITH SYNONYMS = ('flyers last 90 days')
      COMMENT = 'Members who flew in the last 90 days',
    members.flyers_1y AS COUNT(CASE WHEN members.flew_last_1y THEN members.member_id END)
      WITH SYNONYMS = ('flyers last year')
      COMMENT = 'Members who flew in the last year',
    members.flyers_5y AS COUNT(CASE WHEN members.flew_last_5y THEN members.member_id END)
      WITH SYNONYMS = ('flyers last 5 years')
      COMMENT = 'Members who flew in the last 5 years',

    -- ---------- members: redemption horizons (COMPLETED only) ----------
    members.redeemers_30d AS COUNT(CASE WHEN members.completed_txns_30d > 0 THEN members.member_id END)
      COMMENT = 'Members with a completed redemption in the last 30 days',
    members.redeemers_90d AS COUNT(CASE WHEN members.completed_txns_90d > 0 THEN members.member_id END)
      COMMENT = 'Members with a completed redemption in the last 90 days',
    members.redeemers_1y AS COUNT(CASE WHEN members.completed_txns_1y > 0 THEN members.member_id END)
      COMMENT = 'Members with a completed redemption in the last year',
    members.redeemers_5y AS COUNT(CASE WHEN members.completed_txns_5y > 0 THEN members.member_id END)
      COMMENT = 'Members with a completed redemption in the last 5 years',
    members.miles_redeemed_30d AS SUM(members.completed_miles_30d)
      WITH SYNONYMS = ('miles last 30 days', 'completed miles 30d')
      COMMENT = 'Completed miles redeemed in the last 30 days',
    members.miles_redeemed_90d AS SUM(members.completed_miles_90d)
      WITH SYNONYMS = ('miles last 90 days', 'completed miles 90d')
      COMMENT = 'Completed miles redeemed in the last 90 days',
    members.miles_redeemed_1y AS SUM(members.completed_miles_1y)
      WITH SYNONYMS = ('miles last year', 'completed miles 1y')
      COMMENT = 'Completed miles redeemed in the last year',
    members.miles_redeemed_5y AS SUM(members.completed_miles_5y)
      WITH SYNONYMS = ('miles last 5 years', 'completed miles 5y')
      COMMENT = 'Completed miles redeemed in the last 5 years',

    -- ---------- members: lifetime ----------
    members.total_completed_miles AS SUM(members.lifetime_completed_miles)
      WITH SYNONYMS = ('lifetime miles', 'total miles redeemed', 'completed miles')
      COMMENT = 'Lifetime miles from COMPLETED redemptions',
    members.total_pending_miles AS SUM(members.lifetime_pending_miles)
      WITH SYNONYMS = ('pending miles')
      COMMENT = 'Lifetime miles in PENDING redemptions',
    members.total_cancelled_miles AS SUM(members.lifetime_cancelled_miles)
      WITH SYNONYMS = ('cancelled miles')
      COMMENT = 'Lifetime miles in CANCELLED redemptions',
    members.total_redemption_txns AS SUM(members.lifetime_txns)
      WITH SYNONYMS = ('lifetime transactions')
      COMMENT = 'Lifetime redemption transactions of any status',
    members.avg_completed_miles_per_member AS ROUND(SUM(members.lifetime_completed_miles) / NULLIF(COUNT(members.member_id), 0), 2)
      WITH SYNONYMS = ('average miles per member')
      COMMENT = 'Average lifetime completed miles per member',

    -- ---------- redemptions ----------
    redemptions.txn_count AS COUNT(redemptions.txn_id)
      WITH SYNONYMS = ('number of transactions', 'redemption count')
      COMMENT = 'Number of redemption transactions of any status',
    redemptions.txn_completed_count AS COUNT(CASE WHEN redemptions.redemption_status = 'COMPLETED' THEN redemptions.txn_id END)
      COMMENT = 'Number of COMPLETED redemption transactions',
    redemptions.txn_pending_count AS COUNT(CASE WHEN redemptions.redemption_status = 'PENDING' THEN redemptions.txn_id END)
      COMMENT = 'Number of PENDING redemption transactions',
    redemptions.txn_cancelled_count AS COUNT(CASE WHEN redemptions.redemption_status = 'CANCELLED' THEN redemptions.txn_id END)
      COMMENT = 'Number of CANCELLED redemption transactions',
    redemptions.txn_miles_completed AS SUM(CASE WHEN redemptions.redemption_status = 'COMPLETED' THEN redemptions.miles_redeemed ELSE 0 END)
      WITH SYNONYMS = ('miles redeemed', 'completed miles by partner')
      COMMENT = 'Miles in COMPLETED transactions',
    redemptions.txn_miles_pending AS SUM(CASE WHEN redemptions.redemption_status = 'PENDING' THEN redemptions.miles_redeemed ELSE 0 END)
      COMMENT = 'Miles in PENDING transactions',
    redemptions.txn_miles_cancelled AS SUM(CASE WHEN redemptions.redemption_status = 'CANCELLED' THEN redemptions.miles_redeemed ELSE 0 END)
      COMMENT = 'Miles in CANCELLED transactions',
    redemptions.txn_redeeming_members AS COUNT(DISTINCT redemptions.member_id)
      WITH SYNONYMS = ('distinct redeemers')
      COMMENT = 'Distinct members with a transaction in the selected rows',
    redemptions.txn_avg_miles_completed AS ROUND(AVG(CASE WHEN redemptions.redemption_status = 'COMPLETED' THEN redemptions.miles_redeemed END), 0)
      WITH SYNONYMS = ('average redemption size')
      COMMENT = 'Average miles per COMPLETED transaction'
  )

  COMMENT = 'SkyPoints airline loyalty program: member profiles, tiers, flight recency, engagement and mileage redemptions across countries.'

  AI_SQL_GENERATION $$
  - Tier codes: SLV = Silver, GLD = Gold, PLT = Platinum.
  - Country is stored as a code: AU, CAN, IND, PHIL, UK, USA, XX. Map India to IND, United States or America to USA, Australia to AU, Canada to CAN, Philippines to PHIL, United Kingdom or Britain to UK.
  - XX appears to be an unknown or unmapped country bucket. Exclude it from country rankings and comparisons unless the user asks for it, and say so when you exclude it.
  - A stale member is one with no flight in the last 90 days. The active flag (A or I) is a different thing from recent activity.
  - Miles redeemed means COMPLETED miles only. Mention PENDING or CANCELLED miles only if the user asks for them.
  - Engagement segments: HIGHLY_ACTIVE_30D, ACTIVE_90D, COOLING_1Y, DORMANT_OVER_1Y, from most to least engaged.
  - Use the members table for member and country questions, including by country. Use the redemptions table for partner, status and transaction-date questions.
  - Always compute totals and percentages from member level rows with the defined metrics. Never add up pre-computed percentages.
  - Some redemption rows have no matching member (is_orphan_member = TRUE). Include them only when the question is about transactions, not members.
  - For top-N questions without a number, return 10 rows. Round percentages to 2 decimals and miles to whole numbers.
  $$

  AI_QUESTION_CATEGORIZATION $$
  Only answer questions about SkyPoints members, tiers, flights, engagement segments and mileage redemptions. For anything else, say the question is outside what this data covers.
  $$

  AI_VERIFIED_QUERIES (
    top_platinum_india_90d AS (
      QUESTION 'Who are the top 10 Platinum members in India by miles redeemed in the last 90 days?'
      SQL $$
        SELECT member_name, state, completed_miles_90d, engagement_segment
        FROM SKYPOINTS.GOLD.VW_MEMBER_HORIZON_SUMMARY
        WHERE tier_code = 'PLT' AND country = 'IND'
        ORDER BY completed_miles_90d DESC
        LIMIT 10
      $$
    ),
    stale_members_by_country AS (
      QUESTION 'Which countries have the most stale members?'
      SQL $$
        SELECT country,
               COUNT(IFF(stale_member = TRUE, member_id, NULL)) AS stale_members,
               ROUND(100.0 * COUNT(IFF(stale_member = TRUE, member_id, NULL)) / NULLIF(COUNT(member_id), 0), 2) AS stale_member_pct
        FROM SKYPOINTS.GOLD.VW_MEMBER_HORIZON_SUMMARY
        WHERE country <> 'XX'
        GROUP BY country
        ORDER BY stale_members DESC
      $$
    ),
    pending_vs_completed_miles_by_country AS (
      QUESTION 'Show completed versus pending miles by country'
      SQL $$
        SELECT country,
               SUM(lifetime_completed_miles) AS total_completed_miles,
               SUM(lifetime_pending_miles) AS total_pending_miles
        FROM SKYPOINTS.GOLD.VW_MEMBER_HORIZON_SUMMARY
        WHERE country <> 'XX'
        GROUP BY country
        ORDER BY total_completed_miles DESC
      $$
    )
  );

-- ------------------------------------------------------------------
-- Checks
-- ------------------------------------------------------------------
DESC SEMANTIC VIEW SKYPOINTS.GOLD.SKYPOINTS_SV;

SELECT * FROM SEMANTIC_VIEW(
  SKYPOINTS.GOLD.SKYPOINTS_SV
  DIMENSIONS members.country
  METRICS members.total_members, members.stale_members, members.stale_member_pct
)
ORDER BY total_members DESC;

-- Allow the agent role to use it (adjust role as needed)
-- GRANT SELECT ON SEMANTIC VIEW SKYPOINTS.GOLD.SKYPOINTS_SV TO ROLE <your_role>;

SELECT * FROM SEMANTIC_VIEW(
  SKYPOINTS.GOLD.SKYPOINTS_SV
  DIMENSIONS members.country
  METRICS members.total_members, members.stale_members, members.stale_member_pct
)
ORDER BY total_members DESC;
