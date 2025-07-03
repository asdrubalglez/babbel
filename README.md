# Serverless URL Shortener

A fully serverless URL Shortener built on AWS using Terraform and Lambda (Go, Node.js, TypeScript, or Ruby).  
This repository provides infrastructure-as-code, application code in multiple languages, and full documentation.

## 🚀 Quick Start

1. **Clone the repository**  
   ```bash
   git clone <repo-url>
   cd <repo-directory>
   ```

2. **Review documentation**  
   See detailed architecture and usage in `docs/README.md` (including the architecture diagram in `docs/image.png`).

3. **Configure AWS**  
   Ensure AWS credentials are set (`aws configure`) with permissions to manage CloudFront, WAF, API Gateway, Lambda, DynamoDB, CloudWatch, and S3.

4. **Initialize Terraform**  
   ```bash
   terraform init
   ```

5. **Select or create workspace**  
   ```bash
   terraform workspace select dev || terraform workspace new dev
   ```

6. **Deploy infrastructure & Lambda**  
   ```bash
   terraform apply -var="lambda_language=nodejs" -auto-approve
   ```

7. **Test Endpoints**  
   - **Shorten URL** (authenticated):  
     ```bash
     curl -X POST https://<cloudfront-domain>/shorten \
       -H "Authorization: Bearer <JWT_TOKEN>" \
       -d '{"url":"https://example.com"}'
     ```
   - **Redirect** (public):  
     ```bash
     curl -I https://<cloudfront-domain>/<code>
     ```

## 🗂️ Repository Structure

```
.
├── docs/                  # Detailed documentation and architecture diagram
│   ├── README.md
│   └── image.png
├── lambda/                # Lambda function code (choose one language)
│   ├── go/                # Go implementation
│   │   └── main.go
│   ├── node/              # Node.js implementation
│   │   └── index.js
│   ├── typescript/        # TypeScript implementation
│   │   └── index.ts
│   └── ruby/              # Ruby implementation
│       └── app.rb
├── LICENSE                # License information
├── locals.tf              # Terraform locals configuration
├── main.tf                # Root Terraform definitions
├── monitoring.tf          # Monitoring & CloudWatch alarms
├── provider.tf            # Terraform provider configuration
├── variables.tf           # Terraform variable definitions
└── README.md              # This file
```

## ⚙️ Configuration

- **Terraform Variables**  
  - `aws_region`: AWS region (default: `us-east-1`)  
  - `lambda_language`: One of `go`, `nodejs`, `typescript`, `ruby`  
- **Workspaces**: Use `dev`, `staging`, `prod` for environments.

## 🔒 Security & Scaling

- **Auth**: Amazon Cognito User Pool for JWT issuance and API Gateway authorization.  
- **DDoS Protection**: AWS WAF rate-based rules at CloudFront.  
- **Scalability**:  
  - Lambda auto-scales with concurrency  
  - DynamoDB in on-demand mode  
  - CloudFront edge caching

## 📖 Documentation

For full architecture details, code snippets, and best practices, see the documentation in `docs/README.md`.

## 📜 License

This project is licensed under the MIT License. See `LICENSE` for details.
