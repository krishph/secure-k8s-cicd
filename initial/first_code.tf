provider "aws" {
    profile = "default"
    region = "us-east-1"  
}

resource "aws_s3_bucket" "ikrish_tf_course" {
  bucket =  "ikrish-tf-course-d0714"
  acl = "private"
}