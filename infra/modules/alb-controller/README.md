# infra/modules/alb-controller

This directory is reserved for future AWS Load Balancer Controller infrastructure extracted into a dedicated Terraform module.

Today, ALB controller IAM wiring is handled in `infra/env/dev`, and controller installation is handled by the shell apply workflow.
