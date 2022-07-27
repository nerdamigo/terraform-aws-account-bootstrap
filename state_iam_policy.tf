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

// restrict access to bootstrapper path? other modules might take dependency on it, so 
// reading state makes sense - but writing should be an elevated matter