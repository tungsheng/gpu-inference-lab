# Version constraints for the dev environment.
#
# Without these the AWS provider floats, so a provider major release can change
# plan output with no change to this configuration. The exact versions actually
# used are recorded in .terraform.lock.hcl; these constraints are the guard
# rail around what the lock file is allowed to resolve to.

terraform {
  required_version = ">= 1.5.7, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }
}
