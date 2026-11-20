import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsgluedq.transforms import EvaluateDataQuality
from awsglue import DynamicFrame

def sparkSqlQuery(glueContext, query, mapping, transformation_ctx) -> DynamicFrame:
    for alias, frame in mapping.items():
        frame.toDF().createOrReplaceTempView(alias)
    result = spark.sql(query)
    return DynamicFrame.fromDF(result, glueContext, transformation_ctx)
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Default ruleset used by all target nodes with data quality enabled
DEFAULT_DATA_QUALITY_RULESET = """
    Rules = [
        ColumnCount > 0
    ]
"""

# Script generated for node AWS Glue Data Catalog
AWSGlueDataCatalog_node1795168620941 = glueContext.create_dynamic_frame.from_catalog(database="skypoints", table_name="skypoints_encubyterskypoints_members", transformation_ctx="AWSGlueDataCatalog_node1795168620941")

# Script generated for node Change Schema
ChangeSchema_node1795168950976 = ApplyMapping.apply(frame=AWSGlueDataCatalog_node1795168620941, mappings=[("member_name", "string", "member_name", "string"), ("member_id", "string", "member_id", "int"), ("enrollment_date", "string", "enrollment_date", "string"), ("last_flight_date", "long", "last_flight_date", "string"), ("tier_code", "string", "tier_code", "string"), ("agent_name", "string", "agent_name", "string"), ("state", "string", "state", "string"), ("country", "string", "country", "string"), ("dob", "string", "dob", "string"), ("is_active", "string", "is_active", "string")], transformation_ctx="ChangeSchema_node1795168950976")

# Script generated for node SQL Query
SqlQuery25 = '''
SELECT *
FROM myDataSource
WHERE (Member_Name IS NULL OR TRIM(Member_Name) = '')
   OR (Member_Id IS NULL OR TRIM(Member_Id) = '')
   OR (Enrollment_Date IS NULL OR TRIM(Enrollment_Date) = '')
   OR (Last_Flight_Date IS NULL OR TRIM(Last_Flight_Date) = '')
   OR (Tier_Code IS NULL OR TRIM(Tier_Code) = '')
   OR (Agent_Name IS NULL OR TRIM(Agent_Name) = '')
   OR (State IS NULL OR TRIM(State) = '')
   OR (Country IS NULL OR TRIM(Country) = '')
   OR (DOB IS NULL OR TRIM(DOB) = '')
   OR (Is_Active IS NULL OR TRIM(Is_Active) = '')
'''
SQLQuery_node1795169723855 = sparkSqlQuery(glueContext, query = SqlQuery25, mapping = {"myDataSource":ChangeSchema_node1795168950976}, transformation_ctx = "SQLQuery_node1795169723855")

# Script generated for node SQL Query
SqlQuery26 = '''
SELECT *
FROM myDataSource
WHERE Member_Name IS NOT NULL AND TRIM(Member_Name) != ''
  AND Member_Id IS NOT NULL AND TRIM(Member_Id) != ''
  AND Enrollment_Date IS NOT NULL AND TRIM(Enrollment_Date) != ''
  AND Last_Flight_Date IS NOT NULL AND TRIM(Last_Flight_Date) != ''
  AND Tier_Code IS NOT NULL AND TRIM(Tier_Code) != ''
  AND Agent_Name IS NOT NULL AND TRIM(Agent_Name) != ''
  AND State IS NOT NULL AND TRIM(State) != ''
  AND Country IS NOT NULL AND TRIM(Country) != ''
  AND DOB IS NOT NULL AND TRIM(DOB) != ''
  AND Is_Active IS NOT NULL AND TRIM(Is_Active) != ''
'''
SQLQuery_node1795169705477 = sparkSqlQuery(glueContext, query = SqlQuery26, mapping = {"myDataSource":ChangeSchema_node1795168950976}, transformation_ctx = "SQLQuery_node1795169705477")

# Script generated for node Amazon S3
EvaluateDataQuality().process_rows(frame=SQLQuery_node1795169723855, ruleset=DEFAULT_DATA_QUALITY_RULESET, publishing_options={"dataQualityEvaluationContext": "EvaluateDataQuality_node1795168599322", "enableDataQualityResultsPublishing": True}, additional_options={"dataQualityResultsPublishing.strategy": "BEST_EFFORT", "observations.scope": "ALL"})
AmazonS3_node1795170154965 = glueContext.getSink(path="s3://skypoints-members-bad-records", connection_type="s3", updateBehavior="UPDATE_IN_DATABASE", partitionKeys=[], enableUpdateCatalog=True, transformation_ctx="AmazonS3_node1795170154965")
AmazonS3_node1795170154965.setCatalogInfo(catalogDatabase="skypoints",catalogTableName="membersnullrecords")
AmazonS3_node1795170154965.setFormat("glueparquet", compression="snappy")
AmazonS3_node1795170154965.writeFrame(SQLQuery_node1795169723855)
# Script generated for node Amazon S3
EvaluateDataQuality().process_rows(frame=SQLQuery_node1795169705477, ruleset=DEFAULT_DATA_QUALITY_RULESET, publishing_options={"dataQualityEvaluationContext": "EvaluateDataQuality_node1795168599322", "enableDataQualityResultsPublishing": True}, additional_options={"dataQualityResultsPublishing.strategy": "BEST_EFFORT", "observations.scope": "ALL"})
AmazonS3_node1795169899941 = glueContext.getSink(path="s3://skypoint-members-clean", connection_type="s3", updateBehavior="UPDATE_IN_DATABASE", partitionKeys=["country", "state"], enableUpdateCatalog=True, transformation_ctx="AmazonS3_node1795169899941")
AmazonS3_node1795169899941.setCatalogInfo(catalogDatabase="skypoints",catalogTableName="membersClean")
AmazonS3_node1795169899941.setFormat("glueparquet", compression="snappy")
AmazonS3_node1795169899941.writeFrame(SQLQuery_node1795169705477)
job.commit()