# infra

Terraform for the lab's AWS prerequisites.

| Path | Purpose |
| --- | --- |
| `bootstrap/` | creates the S3 bucket that holds remote state; keeps its own state local |
| `env/dev/` | the dev environment: VPC, EKS, Karpenter, and the ALB controller role |
| `modules/` | thin wrappers over upstream modules that carry this lab's conventions |

## Version Constraints

Every configuration pins the Terraform version and the AWS provider major
version in a `versions.tf`. The exact versions in use are recorded in
`.terraform.lock.hcl`; the constraints are the guard rail around what the lock
file may resolve to, so a provider major release cannot change plan output
without a deliberate change here.

## State

`env/dev` uses **local state by default**, which is fine for a single operator
tearing the environment down between runs. It has no locking and no history: if
the state file is lost while infrastructure exists, the environment becomes an
orphaned VPC that has to be cleaned up by hand. `scripts/lib/destroy-recovery.sh`
exists largely to make that recoverable.

Move to remote state before a second person, a second machine, or CI ever runs
an apply.

### Moving to remote state

Create the bucket once:

```bash
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap apply -var state_bucket_name=gpu-inference-lab-tfstate-<account-id>
```

Then point the environment at it:

```bash
cp infra/env/dev/backend_override.tf.example infra/env/dev/backend_override.tf
# edit the bucket name, then:
terraform -chdir=infra/env/dev init -migrate-state
```

`backend_override.tf` is a Terraform override file and matches the existing
`*_override.tf` gitignore rule, so the bucket name stays out of the repository
and the checked-in configuration still works for anyone using local state.

The bucket is created with versioning, encryption, a public access block, and
`prevent_destroy`. Superseded state versions expire after 90 days.
