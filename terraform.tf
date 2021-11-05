provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""
}

#Bucket Creation
resource "aws_s3_bucket" "test20211101cloudfront" {
  bucket = "test20211101cloudfront"
  acl    = "private"
  versioning {
    enabled = true
  }
  tags = {
    Name        = "test20211101cloudfront"
  }
}

#S3 CP thats copy for a test after deploy the cloudfront distribution

resource "null_resource" "s3CP" {
  provisioner "local-exec" {
    command = "aws s3 cp C:\\s3\\ s3://test20211101cloudfront/ --recursive"
  }
  depends_on = [
    aws_s3_bucket.test20211101cloudfront,
  ]
}

# Origin Acess Indentity for acess s3 from cloudfront distribution
resource "aws_cloudfront_origin_access_identity" "OIA_test20211101cloudfront" {
  comment = "OIA For CloudFront Acess on S3 test20211101cloudfront"
  depends_on = [
    aws_s3_bucket.test20211101cloudfront,
  ]
}

# Bucket policy to allow cloudfront to acess the S3 bucket

resource "aws_s3_bucket_policy" "ACL_test20211101cloudfront" {
  bucket = aws_s3_bucket.test20211101cloudfront.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "AllowCloudFront"
    Statement = [
      {
        Sid       = "CloudFrontAllow"
        Effect    = "Allow"
        "Principal": {
            "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.OIA_test20211101cloudfront.id}"
           },
        Action    = "s3:*"
        Resource = "${aws_s3_bucket.test20211101cloudfront.arn}/*",
      },
    ]
  })
  depends_on = [
    aws_cloudfront_origin_access_identity.OIA_test20211101cloudfront,
    aws_s3_bucket.test20211101cloudfront,
  ]
}

# CloudFront distribution
locals {
  s3_origin_id = "myS3Origin"
  
}

resource "aws_cloudfront_distribution" "test20211101cloudfront_Distribution" {
  origin {
    domain_name = aws_s3_bucket.test20211101cloudfront.bucket_regional_domain_name
    origin_id = local.s3_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.OIA_test20211101cloudfront.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = ""
  default_root_object = "root.txt"

  default_cache_behavior {
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  
  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "S3 with CloudFront Test"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  depends_on = [
    aws_cloudfront_origin_access_identity.OIA_test20211101cloudfront,
    aws_s3_bucket.test20211101cloudfront,
    aws_s3_bucket_policy.ACL_test20211101cloudfront,
  ]
}