-- 1. Members Clean (Parquet output from Glue/ETL)
CREATE OR REPLACE STAGE stg_skypoint_members_clean
  URL = 's3://skypoint-members-clean/'
  STORAGE_INTEGRATION = skypoints_s3_int
  FILE_FORMAT = (TYPE = 'PARQUET');

-- 2. Members Bad Records (Quarantine / Rejected records)
CREATE OR REPLACE STAGE stg_skypoints_members_bad
  URL = 's3://skypoints-members-bad-records/'
  STORAGE_INTEGRATION = skypoints_s3_int
  FILE_FORMAT = (TYPE = 'PARQUET');

-- 3. Redemptions Clean
CREATE OR REPLACE STAGE stg_skypoints_redemptions_clean
  URL = 's3://skypoints-redemptions-clean/'
  STORAGE_INTEGRATION = skypoints_s3_int
  FILE_FORMAT = (TYPE = 'PARQUET');

-- 4. Redemption Bad Records (Quarantine / Rejected records)
CREATE OR REPLACE STAGE stg_skypoint_redemption_bad
  URL = 's3://skypoint-redemption-bad-records/'
  STORAGE_INTEGRATION = skypoints_s3_int
  FILE_FORMAT = (TYPE = 'PARQUET');

  