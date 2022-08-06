// IAM Resources in support of deployment to this environment by the environment's owner
//   Restricts access to the bootstrapper's state other than read (so we can ID the bucket, etc)
//   Permissionset:
//     Allows creation of most resources
//     Requires permission boundaries on roles (possibly better suited for SCP, based on tag?)
//   Tagged to identify it as a "deployment" role

/*
dynamodb:GetItem
dynamodb:PutItem
dynamodb:DeleteItem
*/

/*
s3:ListBucket on arn:aws:s3:::mybucket
s3:GetObject on arn:aws:s3:::mybucket/path/to/my/key
s3:PutObject on arn:aws:s3:::mybucket/path/to/my/key
s3:DeleteObject on arn:aws:s3:::mybucket/path/to/my/key
*/