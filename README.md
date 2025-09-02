# Serverless-3Tier-Project
This is a 3Tier project completely based on AWS itself.

AWS Serverless CRUD Project
This project demonstrates a Serverless CRUD Application built with:

AWS Lambda (compute)
Amazon API Gateway (REST API)
Amazon DynamoDB (NoSQL database)
Amazon S3 + CloudFront (frontend hosting)
Terraform (Infrastructure as Code)

 Deployment (Terraform)
Clone this repo:

git clone https://github.com/<your-username>/<your-repo>.git
cd project-root/terraform
Initialize Terraform:

terraform init
Deploy infrastructure:

terraform apply -auto-approve


API Testing with PostmanImport Postman FilesOpen Postman App.Go to Import → Upload Files.Import:postman/serverless_crud_collection.json (collection of CRUD requests)postman/serverless_env.json (environment with base_url)Set EnvironmentIn top-right corner of Postman → select Serverless Project Env.Update base_url with your API Gateway Invoke URL (e.g. https://abc123.execute-api.us-east-1.amazonaws.com/prod).


Run Requests
POST /items → Create item
GET /items → Fetch all items
GET /items/{id} → Fetch single item
PUT /items/{id} → Update item
DELETE /items/{id} → Delete item

 Frontend Access
Open your CloudFront URL in browser → frontend will call API Gateway → Lambda → DynamoDB.
