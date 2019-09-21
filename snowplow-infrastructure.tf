provider "aws" {
	access_key = "${var.access_key}"
	secret_key = "${var.secret_key}"
	region = "${var.region}"
}

resource "aws_s3_bucket" "src" {
  bucket = "${var.env}-${var.website}-lt-src"
  acl    = "public-read"

  tags = {
    Name   = "${var.env}-${var.website}-lt-src"
    Service  = "${var.env}"
    Creator  = "${var.creator}"
    Website = "${var.website}"
  }
}

resource "aws_s3_bucket_object" "object" {
  bucket       = "${aws_s3_bucket.src.bucket}"
  key          = "i"
  source       = "${"${path.module}/files/i"}"
  etag         = "${md5(filebase64("${path.module}/files/i"))}"
  acl          = "public-read"
  content_type = "image/gif"
}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.env}-${var.website}-lt-logs"
  acl    = "private"

  tags = {
    Name   = "${var.env}-${var.website}-lt-logs"
    Service    = "${var.env}"
    Website = "${var.website}"
    creator  = "${var.creator}"
  }
}

resource "aws_cloudfront_distribution" "log_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.src.bucket_regional_domain_name}"
    origin_id   = "S3-${aws_s3_bucket.src.bucket}"
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Cloudfront distribution for snowplow tracking pixel"

  logging_config {
    include_cookies = true
    bucket          = "${aws_s3_bucket.logs.bucket_regional_domain_name}"
    prefix          = "RAW"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.src.bucket}"

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["AF", "AX", "AL", "DZ", "AS", "AD", "AO", "AI", "AQ", "AG", "AR", "AM", "AW", "AU", "AT", "AZ", "BS", "BH", "BD", "BB", "BY", "BE", "BZ", "BJ", "BM", "BT", "BO", "BA", "BW", "BV", "BR", "IO", "BN", "BG", "BF", "BI", "CV", "KH", "CM", "CA", "KY", "CF", "TD", "CL", "CN", "CX", "CC", "CO", "KM", "CG", "CD", "CK", "CR", "CI", "HR", "CU", "CW", "CY", "CZ", "DK", "DJ", "DM", "DO", "EC", "EG", "SV", "GQ", "ER", "EE", "SZ", "ET", "FK", "FO", "FJ", "FI", "FR", "GF", "PF", "TF", "GA", "GM", "GE", "DE", "GH", "GI", "GR", "GL", "GD", "GP", "GU", "GT", "GG", "GN", "GW", "GY", "HT", "HM", "VA", "HN", "HK", "HU", "IS", "IN", "ID", "IR", "IQ", "IE", "IM", "IL", "IT", "JM", "JP", "JE", "JO", "KZ", "KE", "KI", "KP", "KR", "KW", "KG", "LA", "LV", "LB", "LS", "LR", "LY", "LI", "LT", "LU", "MO", "MK", "MG", "MW", "MY", "MV", "ML", "MT", "MH", "MQ", "MR", "MU", "YT", "MX", "FM", "MD", "MC", "MN", "ME", "MS", "MA", "MZ", "MM", "NA", "NR", "NP", "NL", "NC", "NZ", "NI", "NE", "NG", "NU", "NF", "MP", "NO", "OM", "PK", "PW", "PA", "PG", "PY", "PE", "PH", "PN", "PL", "PT", "PR", "QA", "RE", "RO", "RU", "RW", "BL", "KN", "LC", "MF", "PM", "VC", "WS", "SM", "ST", "SA", "SN", "RS", "SC", "SL", "SG", "SX", "SK", "SI", "SB", "SO", "ZA", "GS", "SS", "ES", "LK", "SD", "SR", "SJ", "SE", "CH", "SY", "TJ", "TH", "TL", "TG", "TK", "TO", "TT", "TN", "TR", "TM", "TC", "TV", "UG", "UA", "AE", "GB", "US", "UM", "UY", "UZ", "VU", "VE", "VN", "VG", "VI", "WF", "EH", "YE", "ZM", "ZW"]
    }
  }

  tags = {
    Name   = "${var.env}-${var.creator}-${var.website}-log-dist"
    Service    = "${var.env}"
    Website = "${var.website}"
    Creator  = "${var.creator}"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "lamba_script/"
  output_path = "lambda.zip"
}

data "aws_iam_policy_document" "lambda" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = ["${aws_s3_bucket.logs.arn}/*"]
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.env}-lambda-policy"
  policy      = "${data.aws_iam_policy_document.lambda.json}"
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "${aws_iam_policy.lambda_policy.arn}"
}

resource "aws_iam_role" "lambda_role" {
  name = "LambdaRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.logs.arn}"
}

resource "aws_lambda_function" "lambda" {
  filename      = "${data.archive_file.lambda_zip.output_path}"
  function_name = "${var.env}-lambda"
  handler       = "lambda_function.lambda_handler"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  runtime = "python3.7"
  memory_size = "512"
  timeout = "24"
  role = "${aws_iam_role.lambda_role.arn}"

  tags = {
    Name   = "${var.env}-${var.creator}-${var.website}-log-dist"
    Service    = "${var.env}"
    Website = "${var.website}"
    Creator  = "${var.creator}"
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${aws_s3_bucket.logs.id}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.lambda.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "RAW/"
    filter_suffix       = ".gz"
  }
}

resource "aws_s3_bucket" "ath" {
  bucket = "${var.env}-${var.website}-lt-ath"
  acl = "private"
  tags = {
    Name = "${var.env}-${var.website}-lt-ath"
    Service = "${var.env}"
    Creator = "${var.creator}"
    Website = "${var.website}"
  }
}

resource "aws_athena_workgroup" "wg" {
  name = "${var.env}-${var.website}-wg"
  tags = {
    Name = "${var.env}-${var.website}-wg"
    Service = "${var.env}"
    Creator = "${var.creator}"
    Website = "${var.website}"
  }
}

resource "aws_athena_database" "db" {
  name = "eventsdb${var.creator}"
  bucket = "${aws_s3_bucket.ath.id}"
}

resource "aws_athena_named_query" "create_table" {
  name = "events"
  workgroup = "${aws_athena_workgroup.wg.id}"
  database = "${aws_athena_database.db.name}"
  query = "CREATE EXTERNAL TABLE ${aws_athena_database.db.name}.events (protocolversion string, sdkversion string, collector_tstamp timestamp, adsenselinkingnumber string, hittype string, hitsequencenumber string, documentlocationurl string, userlanguage string, documentencoding string, documenttitle string, user_ipaddress string, screencolors string, screenresolution string, viewportsize string, javaenabled string, geo_country string, geo_city string, geo_zipcode string, geo_latitude string, geo_longitude string, geo_region_name string, usageinfo string, joinid string, trackingcodeversion string, refr_urlscheme string, refr_urlhost string, refr_urlpath string, refr_urlquery string, trackingid string, userid string, r string, gtm string, cachebuster string, useragent string, br_name string, br_family string, br_version string, dvce_type string, dvce_ismobile string, geo_timezone string) ROW FORMAT DELIMITED FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\' LINES TERMINATED BY '\\n' LOCATION 's3://${aws_s3_bucket.logs.bucket}/Converted';"
}
