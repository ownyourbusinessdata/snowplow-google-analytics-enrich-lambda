# snowplow-google-analytics-enrich-lambda
__Lambda function to enrich data collected through Google Analytics Snowplow plugin__

Python based function for aws lambda.

Function parse cloudfrront logs wich requested by Snowplow pixel tracker.

Lambda should triggers on any object creation for bucket with cloudfront logs. Logfiles must be in RAW folder.

Enriched and processed logs puts in same bucket within Converted folder.

# Requirenments

* Terraform 0.12
* AWS user should have following recomended permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:GetPolicyVersion",
                "glue:DeleteDatabase",
                "iam:DeletePolicy",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "athena:*",
                "iam:ListInstanceProfilesForRole",
                "cloudfront:GetDistribution",
                "iam:PassRole",
                "iam:DetachRolePolicy",
                "iam:ListAttachedRolePolicies",
                "cloudfront:UpdateDistribution",
                "iam:GetRole",
                "iam:GetPolicy",
                "glue:GetTables",
                "s3:*",
                "cloudfront:TagResource",
                "iam:DeleteRole",
                "cloudfront:CreateDistribution",
                "glue:GetDatabases",
                "iam:CreatePolicy",
                "glue:GetDatabase",
                "iam:ListPolicyVersions",
                "cloudfront:ListTagsForResource",
                "glue:CreateDatabase",
                "lambda:*",
                "cloudfront:DeleteDistribution"
            ],
            "Resource": "*"
        }
    ]
}
```

# Configuring terraform script

File ```variables.tf``` contains all configurable variables for script:

* __env__ - Service tag. May be used as billing reports tag.
* __creator__ - Personalization tag.
* __website__ - Website FQDN for plowing.
* __access_key__ - AWS user access key.
* __primary_domain__ - Cloudfront distribution CNAME.
* __secret_key__ - AWS user secret key.
* __region__ - AWS region.

# Deploying infrastructure

Inside repo directory run:

```bash
terraform init
terraform apply
```

Terraform will create:

* 3 Buckets:
  1. With __lt-src__ suffix. Public accessible for reading. Contains 1x1 pixel image for snowplow POST data.
  2. With __lt-logs__ suffix. Using for storing: cloudfront logs with __RAW__ prefix, enriched snowplow data with __Converted__ prefix and maxmind GeoLite2 database.
  3. With __lt-ath__ suffix. Using for storing Athena query results.

* Cloudfront distribution with __lt-src__ bucket as target and __lt-logs__ bucket for logs storing.

* Lambda function wich triggers on any __lt-logs__ bucket object creation with prefix __RAW__ and suffix __.gz__.

* Athena workgroup with suffix __wg__

* Athena database with prefix __eventsdb__

* Athena saved query with name __events__

To complete infrastructure deployment run created saved athena query in created workgroup, it will create table with enriched snowplow events.

# Configuring snowplow Google Analytics plugin:

Snowplow pixel GA plugin optimized for working with cloudfront looks like:

```javascript
function() {
  var endpoint = 'https://d28zcvgo2jno01.cloudfront.net/i';
  return function(model) {    
    var globalSendTaskName = '_' + model.get('trackingId') + '_sendHitTask';
    var originalSendHitTask = window[globalSendTaskName] = window[globalSendTaskName] || model.get('sendHitTask');
    model.set('sendHitTask', function(sendModel) {
      var payload = sendModel.get('hitPayload');
      originalSendHitTask(sendModel);
      var request = new XMLHttpRequest();
      var path = endpoint + '?' + payload;
      request.open('GET', path, true);
      request.setRequestHeader('Content-type', 'text/plain; charset=UTF-8');
      request.send(payload);
    });
  };
}
```

You have to change __endpoint__ to created cloudfront domain name and add code on pages you wanted to track with snowplow.