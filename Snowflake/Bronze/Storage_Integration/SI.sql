CREATE OR REPLACE STORAGE INTEGRATION skypoints_s3_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::527302818872:role/skypointsrole'
  STORAGE_ALLOWED_LOCATIONS = (
    's3://skypoint-members-clean/',
    's3://skypoint-redemption-bad-records/',
    's3://skypoints-members-bad-records/',
    's3://skypoints-redemptions-clean/'
  );

DESC STORAGE INTEGRATION skypoints_s3_int;