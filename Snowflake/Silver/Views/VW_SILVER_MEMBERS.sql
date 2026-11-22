create or replace view SKYPOINTS.SILVER.VW_SILVER_MEMBERS(
	MEMBER_ID,
	MEMBER_NAME,
	ENROLLMENT_DATE,
	LAST_FLIGHT_DATE,
	TIER_CODE,
	AGENT_NAME,
	DOB,
	AGE,
	STALE_MEMBER,
	IS_ACTIVE,
	COUNTRY,
	STATE,
	CREATED_AT,
	UPDATED_AT
) as
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
            DATEDIFF('year', dob, CURRENT_DATE())
                - IFF(TO_CHAR(CURRENT_DATE(), 'MMDD') < TO_CHAR(dob, 'MMDD'), 1, 0),
            NULL
        ) AS age,
        IFF(
            last_flight_date IS NOT NULL AND DATEDIFF('day', last_flight_date, CURRENT_DATE()) > 90,
            TRUE,
            FALSE
        ) AS stale_member,
        is_active,
        country,
        state,
        created_at,
        updated_at
    FROM silver.silver_members;