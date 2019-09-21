# snowplow-google-analytics-enrich-lambda
__Lambda function to enrich data collected through Google Analytics Snowplow plugin__

Python based function for aws lambda.

Function parse cloudfrront logs wich requested by Snowplow pixel tracker.

Lambda should triggers on any object creation for bucket with cloudfront logs. Logfiles must be in RAW folder.

Enriched and processed logs puts in same bucket within Converted folder.

