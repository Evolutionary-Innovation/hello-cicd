# Roadmap

Ordered by value for projects built on the template. Nothing here is required for v1.0.

## Next (v1.1)

- **TLS and a real hostname**: Route 53 + ACM with CloudFront or an Application Load Balancer; restrict the security group to it; health check over HTTPS.
- **Branch protection and CODEOWNERS** committed as repository settings (Terraform GitHub provider) rather than by hand.
- **Pin GitHub Actions by commit SHA** with Dependabot updates.
- **Monitoring**: CloudWatch alarms (status check, `/health` canary), SNS notification, log shipping from the container.

## Later (v1.x)

- **Host housekeeping**: image pruning (or a periodic instance refresh) so the root volume never fills.
- **Zero-downtime deploys**: run the new container beside the old one and switch, or use an ALB with two targets.
- **Scheduled patching**: a workflow that runs `terraform apply -replace=aws_instance.web` with an approval step.
- **ECR scan gate**: fail the build on high/critical findings.
- **Private subnet and own VPC** instead of the default VPC.
- **Customer-managed KMS** for EBS and state when compliance requires.

## Possible v2.0 directions

- **ECS on Fargate** or App Runner in place of EC2 + Docker, keeping the same bootstrap/OIDC/pipeline shape.
- **Multi-environment**: environment-specific state keys and roles from one repository, with promotion between them.
- **Multi-project account**: bootstrap that manages the shared OIDC provider once and creates per-project roles.
- **Template sync tooling** (Copier or a GitHub template repository) to update downstream projects.
- **Config-as-input**: replacing the committed tfvars/backend values with a single `project.yaml`.
