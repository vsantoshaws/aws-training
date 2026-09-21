# Troubleshooting

Issues actually hit (and fixed) while standing up this stack, in the order you're likely to hit them.

## `terraform init` fails: `does not have a provider named registry.terraform.io/hashicorp/opensearch`

A child module uses the `opensearch` provider but doesn't declare its source, so Terraform defaults to the `hashicorp/` namespace instead of inheriting `opensearch-project/opensearch` from the root `versions.tf`. Fixed by adding a `required_providers` block to `modules/opensearch_vectorstore/versions.tf`. If you fork this and add a new module that uses a non-`hashicorp` provider, it needs its own `required_providers` block too — this isn't inherited automatically from the root module.

## First `terraform apply` fails creating the OpenSearch vector index

The `opensearch` provider is configured against the OpenSearch Serverless collection's endpoint, which is only known once the collection exists — not at plan time. On a brand-new collection, data-access-policy propagation can lag behind collection creation. **Just re-run `terraform apply`** — it picks up where it left off. This is a well-known ordering quirk in the Terraform/OpenSearch Serverless ecosystem, not specific to this config (there's already a `time_sleep` of 60s built in to reduce how often this happens).

## `aws_s3_bucket` hangs on "Still creating..." for 10+ minutes

If you (or a previous run) created and deleted a bucket with the exact same name shortly before, S3 rejects the new `CreateBucket` call with `409 OperationAborted: A conflicting conditional operation is currently in progress against this resource` while it finishes cleaning up internally. The AWS SDK treats this as retryable and silently retries with backoff for a long time — no error shows up until it either clears or exhausts retries. This isn't a bug in the config; either wait it out or check with `aws s3api head-bucket --bucket <name> --region <region>` in a separate terminal.

## No Docker / Docker Desktop needs admin rights

`modules/ecr_agent_image` shells out to `docker buildx build --push`, which needs a working Docker CLI + daemon on the machine running `apply`. If Docker Desktop's installer wants admin credentials you don't have, use **Colima** instead (no privileged installer, uses macOS's built-in Virtualization framework):

```bash
brew install docker docker-buildx colima
colima start --arch aarch64 --vm-type=vz --cpu 2 --memory 4
```

Register the buildx plugin once (`~/.docker/config.json`):
```json
{ "cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"] }
```

**Colima's VM does not survive a reboot** unless started as a background service. If you see `failed to connect to the docker API at unix:///.../docker.sock: ... no such file or directory`, Colima has simply stopped — run `colima start` again, or avoid the recurrence with:
```bash
brew services start colima
```

## Agent invocation returns 500: `ResourceNotFoundException ... model version has reached the end of its life`

The Bedrock model pinned in `bedrock_model_id` has been retired by AWS. Check CloudWatch Logs for the AgentCore Runtime (`/aws/bedrock-agentcore/runtimes/<runtime-name>-DEFAULT`) for the exact error — it names the dead model ID. Fix: list current models/inference profiles and update `bedrock_model_id` in `terraform.tfvars` and `variables.tf`:
```bash
aws bedrock list-inference-profiles --region <region> \
  --query 'inferenceProfileSummaries[?contains(inferenceProfileId, `anthropic`)].inferenceProfileId'
```
This only changes an environment variable on the running container — **no image rebuild needed**, just `terraform apply -target=module.agentcore_runtime.aws_bedrockagentcore_agent_runtime.agent`.

## Agent invocation returns 500: `AccessDeniedException ... foundation-model/<model> because no identity-based policy allows ...` (note the ARN's region doesn't match `var.aws_region`)

Cross-region inference profiles (`us.anthropic...`) route the actual request to whichever underlying region has capacity — `us-east-1`, `us-east-2`, `us-west-2`, etc. — and IAM checks the permission against **that region's** foundation-model ARN, not just your configured region. The runtime's IAM policy in `modules/agentcore_runtime/main.tf` grants the foundation-model action with a region **wildcard** (`arn:aws:bedrock:*::foundation-model/*`) specifically to cover this — if you ever narrow that back to a single region, this error will come back.

## `boto3.client("bedrock-agentcore", ...)` raises `UnknownServiceError`

The chat UI's `requirements.txt` (generated inline in `modules/ec2_chat_ui/templates/user_data.sh.tpl`) must resolve a `boto3`/`botocore` version recent enough to know about the `bedrock-agentcore` service model — it's a newer AWS service. Pin it with a floor (`boto3>=1.35.36`), not an exact pin, or a stale exact version will predate AgentCore's addition to botocore's service catalog. Symptom: `chat-ui.service` restart-loops forever (`journalctl -u chat-ui` shows the worker crashing on import), so even `curl localhost:8000` fails on the instance itself — that's the tell that this is an app/dependency issue, not a security-group/network issue.

## Chat UI unreachable from the browser, but `curl localhost:8000` also fails **on the instance itself**

This rules out the security group / network path entirely — the problem is the app not actually listening. Check, in order:
```bash
sudo systemctl status chat-ui.service      # does the unit exist / is it crash-looping?
sudo journalctl -u chat-ui.service -n 100 --no-pager   # why
sudo tail -150 /var/log/cloud-init-output.log          # did user_data itself fail partway?
sudo ss -tlnp | grep 8000                               # is anything bound to the port at all?
```
`user_data` runs with `set -euo pipefail`, so any failed step (a `dnf`/`pip` failure) silently aborts the rest of the script, including creating the systemd unit at all.

## Raw JSON shows up in the chat UI instead of the reply text

The agent entrypoint (`agent_app/app.py`) returns `{"result": {"role": "assistant", "content": [...]}}`. The chat UI's response parser must unwrap the `"result"` key — if it looks for a different key (e.g. `"output"`), every extraction path fails silently and falls back to dumping the raw JSON. If you change the agent's return shape, update `_extract_reply_text` in `web_ui/app.py` to match.

## EC2 instance stopped / no public IP

Without an Elastic IP, a stopped instance loses its public IP and gets a **new** one each time it's started — `terraform output chat_ui_public_ip` will be empty while stopped. Start it and re-check:
```bash
aws ec2 start-instances --instance-ids <id> --region <region>
aws ec2 wait instance-running --instance-ids <id> --region <region>
```

## Connecting to the EC2 instance

By default (`allowed_ssh_cidrs = []`, no `ec2_key_pair_name`), SSH is closed and the intended access path is **SSM Session Manager** (the instance role already has `AmazonSSMManagedInstanceCore`):
```bash
aws ssm start-session --target <instance-id> --region <region>
```
If you need real SSH, set `ec2_key_pair_name` and open `allowed_ssh_cidrs` in `terraform.tfvars`. Changing `ec2_key_pair_name` **replaces the instance** (`key_name` can only be set at launch, not updated in place) — expect a new instance ID and public IP.

## Terraform state went (unexpectedly) empty

If `terraform state list` comes back empty but `terraform.tfstate.backup` still has all your resources, compare `lineage` between the two files (`python3 -c "import json; print(json.load(open('terraform.tfstate')).get('lineage'))"`). A matching lineage with a higher `serial` and zero resources is consistent with a real `terraform destroy` having run — **verify against AWS directly** (`aws ec2 describe-instances`, etc.) before running `apply` again, since applying against an empty state that doesn't match reality can try to recreate resources that already exist (bucket/ECR-repo name collisions) instead of cleanly rebuilding.
