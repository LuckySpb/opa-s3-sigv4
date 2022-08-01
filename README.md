# opa-s3-sigv4
Helper project to help fix the issue with S3 sigV4 signature for open policy agent 
https://github.com/open-policy-agent/opa/issues/

# TLDR
To reproduce error: configure env variables for aws credentials and run:
```shell
opa run --server --config-file opa-config-auth-with-version.yaml --log-level debug
```
S3 buckets are already configured to properly reproduce the issue

# Details

## Public bucket (no sigv4 needed)
Example with version ID will work, as S3 bucket doesn't require any IAM authentication
### Latest - no object version
```shell

# latest
#https://opa-s3-test1-public.s3.amazonaws.com/authz.tar.gz
opa run --server --config-file opa-config-public-no-version.yaml --log-level debug
curl localhost:8181/v1/data
```
Output
```json
{"result":{"authz":{"allow":[]},"users":[{"id":"bob","name":"Robert Downey Jr"},{"id":"robobob","name":"Haven't survived Avengers"}]}}
```

### Specific object version
```
# specific version
# https://opa-s3-test1-public.s3.amazonaws.com/authz.tar.gz?versionId=0LdyQdHFVgm_GgzSb4seaoOjBDwl3Fgx

opa run --server --config-file opa-config-public-with-version.yaml --log-level debug
curl localhost:8181/v1/data
```
Output
```json
{"result":{"authz":{"allow":[]},"users":[{"id":"bob","name":"Robert Downey Jr"}]}}
```

## Private bucket - AuthN needed
https://opa-s3-test2-auth.s3.amazonaws.com/authz.tar.gz

Set up env vars with 
```shell
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
```

Files are accessible for  authenticated aws user by checking aws:PrincipalType==AssumedRole  
Bucket policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAnyAuthenticated",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:Get*",
        "s3:List*"
      ],
      "Resource": [
        "arn:aws:s3:::opa-s3-test2-auth",
        "arn:aws:s3:::opa-s3-test2-auth/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:PrincipalType": [
            "Account",
            "User",
            "AssumedRole"
          ]
        }
      }
    }
  ]
}
```

### Latest - no object version
~/.aws/credentials should have credentials for IAM role
OPA config
```yaml
  credentials:
    s3_signing:
      environment_credentials: {}
```
```shell
#https://opa-s3-test1-public.s3.amazonaws.com/authz.tar.gz
opa run --server --config-file opa-config-auth-no-version.yaml --log-level debug
curl localhost:8181/v1/data
```

### With version
```shell
opa run --server --config-file opa-config-auth-with-version.yaml --log-level debug
```
You will see forbidden errors
```json
{"headers":{"Content-Type":["application/xml"],"Date":["Mon, 01 Aug 2022 22:47:00 GMT"],"Server":["AmazonS3"],"X-Amz-Id-2":["sG+eb72ODb7SjFP5bisy3VXgc9SJTpaZFMpLDzdQdj4SA/3Dyu2cUsb8pmQWvpJTVYimJTMUQVk="],"X-Amz-Request-Id":["9K33J6S2KB7BY08D"]},"level":"debug","method":"GET","msg":"Received response.","status":"403 Forbidden","time":"2022-08-01T18:47:01-04:00","url":"https://opa-s3-test2-auth.s3.amazonaws.com/authz.tar.gz?versionId=M1JY81qsF_EPX_u2nJcsruFhl9XyB6NK"}
```
However, with aws cli you can get same version id successfully
```shell
aws s3api get-object --bucket opa-s3-test2-auth --key authz.tar.gz --version-id M1JY81qsF_EPX_u2nJcsruFhl9XyB6NK authz-versioned.tar.gz

# returns content of
https://opa-s3-test2-auth.s3.amazonaws.com/authz.tar.gz?versionId=M1JY81qsF_EPX_u2nJcsruFhl9XyB6NK

```

## how to
### run local

```shell
opa run --server --bundle bundle

curl localhost:8181/v1/data
```

### create bundle
tar -zcvf authzv2.tar -C bundleV2 .

### Download from S3 with aws cli
```
aws s3api get-object --bucket opa-s3-test2-auth --key authz.tar.gz froms3.tar.gz
```
