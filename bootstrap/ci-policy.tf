# Least-privilege permissions for the GitHub Actions role.
#
# Scope: one project. Mutating EC2/SSM actions are limited to resources tagged
# project=<project_name> (applied to every resource by the provider default_tags),
# IAM to the instance role/profile, ECR to the project repository, S3 to the
# project's state prefix. Nothing here can touch the bootstrap stack or its state.
data "aws_caller_identity" "current" {}

locals {
  github_role_name = coalesce(var.github_role_name, "${var.project_name}-github-actions")

  account_id   = data.aws_caller_identity.current.account_id
  region       = var.aws_region
  p            = var.project_name
  ec2_role_arn = "arn:aws:iam::${local.account_id}:role/${local.p}-ec2"
  profile_arn  = "arn:aws:iam::${local.account_id}:instance-profile/${local.p}-ec2"
  ecr_repo_arn = "arn:aws:ecr:${local.region}:${local.account_id}:repository/${local.p}"
  state_bucket = "arn:aws:s3:::${var.state_bucket_name}"

  in_region = { StringEquals = { "aws:RequestedRegion" = local.region } }

  ci_policy_statements = [
    {
      Sid      = "TerraformStateList"
      Effect   = "Allow"
      Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
      Resource = local.state_bucket
    },
    {
      Sid      = "TerraformStateObjects"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      Resource = "${local.state_bucket}/${local.p}/*"
    },
    {
      Sid       = "Ec2ReadAndCreate"
      Effect    = "Allow"
      Action    = ["ec2:Describe*", "ec2:GetInstanceUefiData", "ec2:RunInstances", "ec2:CreateSecurityGroup", "ec2:AllocateAddress", "ec2:AssociateAddress", "ec2:DisassociateAddress", "ec2:AssociateIamInstanceProfile", "ec2:ReplaceIamInstanceProfileAssociation", "ec2:DisassociateIamInstanceProfile", "ec2:ModifyVolume"]
      Resource  = "*"
      Condition = local.in_region
    },
    {
      Sid    = "Ec2TagOnCreate"
      Effect = "Allow"
      Action = "ec2:CreateTags"
      Resource = [
        "arn:aws:ec2:${local.region}:${local.account_id}:instance/*",
        "arn:aws:ec2:${local.region}:${local.account_id}:volume/*",
        "arn:aws:ec2:${local.region}:${local.account_id}:network-interface/*",
        "arn:aws:ec2:${local.region}:${local.account_id}:security-group/*",
        "arn:aws:ec2:${local.region}:${local.account_id}:elastic-ip/*",
      ]
      Condition = {
        StringEquals = {
          "aws:RequestedRegion" = local.region
          "ec2:CreateAction"    = ["RunInstances", "CreateSecurityGroup", "AllocateAddress"]
        }
      }
    },
    {
      Sid    = "Ec2ManageProjectResources"
      Effect = "Allow"
      Action = [
        "ec2:CreateTags", "ec2:DeleteTags",
        "ec2:StartInstances", "ec2:StopInstances", "ec2:TerminateInstances",
        "ec2:ModifyInstanceAttribute", "ec2:ModifyInstanceMetadataOptions",
        "ec2:DeleteSecurityGroup", "ec2:ModifySecurityGroupRules",
        "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
        "ec2:UpdateSecurityGroupRuleDescriptionsIngress", "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
        "ec2:ReleaseAddress",
      ]
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:RequestedRegion"     = local.region
          "ec2:ResourceTag/project" = local.p
        }
      }
    },
    {
      Sid    = "IamInstanceRoleAndProfile"
      Effect = "Allow"
      Action = [
        "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateAssumeRolePolicy",
        "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
        "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
        "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
        "iam:TagInstanceProfile", "iam:UntagInstanceProfile", "iam:ListInstanceProfileTags",
      ]
      Resource = [local.ec2_role_arn, local.profile_arn]
    },
    {
      Sid      = "IamAttachOnlyApprovedManagedPolicies"
      Effect   = "Allow"
      Action   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
      Resource = local.ec2_role_arn
      Condition = {
        ArnEquals = {
          "iam:PolicyARN" = [
            "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
            "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
          ]
        }
      }
    },
    {
      Sid       = "IamPassInstanceRole"
      Effect    = "Allow"
      Action    = "iam:PassRole"
      Resource  = local.ec2_role_arn
      Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } }
    },
    {
      Sid      = "EcrLogin"
      Effect   = "Allow"
      Action   = "ecr:GetAuthorizationToken"
      Resource = "*"
    },
    {
      Sid    = "EcrProjectRepository"
      Effect = "Allow"
      Action = [
        "ecr:CreateRepository", "ecr:DeleteRepository", "ecr:DescribeRepositories",
        "ecr:ListTagsForResource", "ecr:TagResource", "ecr:UntagResource",
        "ecr:PutImageScanningConfiguration", "ecr:PutImageTagMutability",
        "ecr:PutLifecyclePolicy", "ecr:GetLifecyclePolicy", "ecr:DeleteLifecyclePolicy",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeImages", "ecr:ListImages", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload", "ecr:PutImage",
      ]
      Resource = local.ecr_repo_arn
    },
    {
      Sid      = "SsmRunShellDocument"
      Effect   = "Allow"
      Action   = "ssm:SendCommand"
      Resource = "arn:aws:ssm:${local.region}::document/AWS-RunShellScript"
    },
    {
      Sid      = "SsmRunCommandOnProjectInstances"
      Effect   = "Allow"
      Action   = "ssm:SendCommand"
      Resource = "arn:aws:ec2:${local.region}:${local.account_id}:instance/*"
      Condition = {
        StringEquals = {
          "aws:RequestedRegion"     = local.region
          "ssm:resourceTag/project" = local.p
        }
      }
    },
    {
      Sid       = "SsmReadCommandResults"
      Effect    = "Allow"
      Action    = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations", "ssm:ListCommands", "ssm:DescribeInstanceInformation"]
      Resource  = "*"
      Condition = local.in_region
    },
  ]
}

resource "aws_iam_policy" "github_actions" {
  name        = "${local.github_role_name}-policy"
  description = "Least-privilege permissions for the ${local.p} CI/CD pipeline"
  policy      = jsonencode({ Version = "2012-10-17", Statement = local.ci_policy_statements })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_terraform.name
  policy_arn = aws_iam_policy.github_actions.arn
}
