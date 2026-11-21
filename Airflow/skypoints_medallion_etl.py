from datetime import datetime, timedelta
from airflow import DAG
from airflow.models.baseoperator import chain
from airflow.providers.snowflake.operators.snowflake import (
    SnowflakeOperator,
    SnowflakeCheckOperator,
)

SNOWFLAKE_CONN_ID = "snowflake_default"

default_args = {
    "owner": "iishaan",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=3),
}

with DAG(
    dag_id="skypoints_medallion_etl",
    description="End-to-end Bronze -> Silver -> Gold Medallion ETL for SkyPoints Loyalty Program",
    default_args=default_args,
    start_date=datetime(2026, 11, 20),
    schedule="@daily",
    catchup=False,
    max_active_runs=1,
    tags=["skypoints", "medallion", "snowflake", "dq"],
) as dag:

    # =========================================================================
    # STAGE 1: Bronze Raw Load (Parallel: Members & Redemptions)
    # =========================================================================
    load_bronze_members = SnowflakeOperator(
        task_id="load_bronze_members",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="CALL bronze.sp_load_bronze_members();",
        autocommit=True,
    )

    load_bronze_redemptions = SnowflakeOperator(
        task_id="load_bronze_redemptions",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="CALL bronze.sp_load_bronze_redemptions();",
        autocommit=True,
    )

    # =========================================================================
    # STAGE 2: Silver Source Incremental Staging (Parallel)
    # =========================================================================
    stage_silver_members = SnowflakeOperator(
        task_id="stage_silver_members",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="CALL silver.sp_load_silver_members_source();",
        autocommit=True,
    )

    stage_silver_redemptions = SnowflakeOperator(
        task_id="stage_silver_redemptions",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="CALL silver.sp_load_silver_redemptions_source();",
        autocommit=True,
    )

    # =========================================================================
    # STAGE 3: Silver Source Deduplication & DQ Quarantine (Parallel)
    # =========================================================================
    clean_silver_members = SnowflakeOperator(
        task_id="clean_silver_members",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="CALL silver.sp_clean_silver_members_source();",
        autocommit=True,
    )

    clean_silver_redemptions = SnowflakeOperator(
        task_id="clean_silver_redemptions",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="CALL silver.sp_clean_silver_redemptions_source();",
        autocommit=True,
    )

    # =========================================================================
    # STAGE 4: Silver Master Tables Upsert (MERGE - Parallel)
    # =========================================================================
    merge_silver_members = SnowflakeOperator(
        task_id="merge_silver_members",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="CALL silver.sp_merge_silver_members();",
        autocommit=True,
    )

    merge_silver_redemptions = SnowflakeOperator(
        task_id="merge_silver_redemptions",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="CALL silver.sp_merge_silver_redemptions();",
        autocommit=True,
    )

    # =========================================================================
    # STAGE 4.5: Silver Master Data Quality Gates (SnowflakeCheckOperator)
    # =========================================================================
    dq_check_silver_members = SnowflakeCheckOperator(
        task_id="dq_check_silver_members",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="""
            SELECT
                COUNT(*) > 0
                AND COUNT(*) = COUNT(DISTINCT member_id)
                AND COUNT_IF(
                    member_name IS NULL
                    OR enrollment_date IS NULL
                    OR (last_flight_date IS NOT NULL AND last_flight_date < enrollment_date)
                    OR (last_flight_date IS NOT NULL AND last_flight_date > CURRENT_DATE())
                    OR (tier_code IS NOT NULL AND tier_code NOT IN ('SLV', 'GLD', 'PLT'))
                ) = 0
            FROM silver.silver_members;
        """,
    )

    dq_check_silver_redemptions = SnowflakeCheckOperator(
        task_id="dq_check_silver_redemptions",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="""
            SELECT
                COUNT(*) > 0
                AND COUNT(*) = COUNT(DISTINCT txn_id)
                AND COUNT_IF(
                    member_id IS NULL
                    OR txn_date IS NULL
                    OR txn_date > CURRENT_DATE()
                    OR miles_redeemed <= 0
                    OR status NOT IN ('COMPLETED', 'PENDING', 'CANCELLED')
                ) = 0
            FROM silver.silver_redemptions;
        """,
    )

    # =========================================================================
    # STAGE 5: Gold Per-Country Tables Sync & Country Horizon Views
    # =========================================================================
    sync_gold_country_tables = SnowflakeOperator(
        task_id="sync_gold_country_tables",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="CALL gold.sp_sync_country_member_tables();",
        autocommit=True,
    )

    create_gold_country_views = SnowflakeOperator(
        task_id="create_gold_country_views",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="CALL gold.sp_create_country_horizon_views();",
        autocommit=True,
    )

    # =========================================================================
    # STAGE 5.5: Gold Layer Reconciliation & Horizon DQ Checks
    # =========================================================================
    dq_check_gold_country_reconciliation = SnowflakeCheckOperator(
        task_id="dq_check_gold_country_reconciliation",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="""
            WITH silver_summary AS (
                SELECT
                    COUNT(*) AS silver_cnt,
                    COUNT(DISTINCT COALESCE(NULLIF(TRIM(UPPER(country)), ''), 'UNKNOWN')) AS silver_countries
                FROM silver.silver_members
            ),
            gold_table_summary AS (
                SELECT COUNT(*) AS gold_tables
                FROM information_schema.tables
                WHERE table_schema = 'GOLD'
                  AND table_type = 'BASE TABLE'
                  AND STARTSWITH(table_name, 'TABLE_')
            ),
            gold_view_summary AS (
                SELECT
                    COALESCE(SUM(total_members), 0) AS gold_cnt,
                    COUNT(*) AS gold_view_countries
                FROM gold.vw_country_wise_analysis
            )
            SELECT
                s.silver_cnt = v.gold_cnt
                AND s.silver_countries = t.gold_tables
                AND s.silver_countries = v.gold_view_countries
            FROM silver_summary s
            CROSS JOIN gold_table_summary t
            CROSS JOIN gold_view_summary v;
        """,
    )

    dq_check_gold_horizon_views = SnowflakeCheckOperator(
        task_id="dq_check_gold_horizon_views",
        snowflake_conn_id=SNOWFLAKE_CONN_ID,
        sql="""
            SELECT
                COUNT(*) > 0
                AND COUNT_IF(
                    total_members <= 0
                    OR completed_miles_30d < 0
                    OR completed_miles_1y < completed_miles_90d
                    OR completed_miles_5y < completed_miles_1y
                ) = 0
            FROM gold.vw_country_horizon_analysis;
        """,
    )

    # =========================================================================
    # PIPELINE DEPENDENCIES
    # =========================================================================
    chain(
        load_bronze_members,
        stage_silver_members,
        clean_silver_members,
        merge_silver_members,
        dq_check_silver_members,
    )

    chain(
        load_bronze_redemptions,
        stage_silver_redemptions,
        clean_silver_redemptions,
        merge_silver_redemptions,
        dq_check_silver_redemptions,
    )

    (
        [dq_check_silver_members, dq_check_silver_redemptions]
        >> sync_gold_country_tables
        >> create_gold_country_views
        >> [dq_check_gold_country_reconciliation, dq_check_gold_horizon_views]
    )