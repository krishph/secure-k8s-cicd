# Optional EKS and ECR walkthrough

This path assumes an existing EKS cluster, suitable worker nodes, network access,
an authorized AWS CLI session, and Kubernetes access. It creates two ECR repositories
when you run the commands. Provisioning the cluster, IAM, and VPC is outside this
prototype. These commands have not been executed. Replace example values first.

## Build and publish

Use the CPU architecture of your worker nodes. The example selects amd64, including
when building on an Apple Silicon laptop. Use arm64 instead for Graviton nodes.

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=123456789012     # Replace with your account
export EKS_CLUSTER_NAME=your-cluster
export RELEASE_TAG=demo-001           # Choose a new tag for each release
export ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

aws sts get-caller-identity
aws ecr create-repository --region "$AWS_REGION" \
  --repository-name securecicd/frontend --image-tag-mutability IMMUTABLE
aws ecr create-repository --region "$AWS_REGION" \
  --repository-name securecicd/backend --image-tag-mutability IMMUTABLE
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker build --platform linux/amd64 -t "$ECR_REGISTRY/securecicd/frontend:$RELEASE_TAG" app/frontend
docker build --platform linux/amd64 -t "$ECR_REGISTRY/securecicd/backend:$RELEASE_TAG" app/backend
bash scripts/scan.sh "$ECR_REGISTRY/securecicd/frontend:$RELEASE_TAG" \
  "$ECR_REGISTRY/securecicd/backend:$RELEASE_TAG" docker.io/library/redis:7.4-alpine
docker push "$ECR_REGISTRY/securecicd/frontend:$RELEASE_TAG"
docker push "$ECR_REGISTRY/securecicd/backend:$RELEASE_TAG"
```

If the repositories already exist, skip creation. ECR authentication and pushing
follow the [AWS ECR instructions](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html).
No long-lived AWS key belongs in this repository.

## Render and deploy your release

Add both **exact repository names** to `approved_repositories` in
`policies/kubernetes.rego`, for example
`123456789012.dkr.ecr.us-east-1.amazonaws.com/securecicd/frontend` and the corresponding
backend repository. Keep the demo repositories while using the supplied fixtures.

Resolve application digests from ECR and Redis's digest from your local pull:

```bash
FRONTEND_DIGEST=$(aws ecr describe-images --region "$AWS_REGION" \
  --repository-name securecicd/frontend --image-ids imageTag="$RELEASE_TAG" \
  --query 'imageDetails[0].imageDigest' --output text)
BACKEND_DIGEST=$(aws ecr describe-images --region "$AWS_REGION" \
  --repository-name securecicd/backend --image-ids imageTag="$RELEASE_TAG" \
  --query 'imageDetails[0].imageDigest' --output text)
docker pull docker.io/library/redis:7.4-alpine
REDIS_REFERENCE=$(docker image inspect docker.io/library/redis:7.4-alpine \
  --format '{{index .RepoDigests 0}}')
```

Create `build/eks-values.yaml` (the directory is ignored by Git). Replace the strings
below with the actual references, including real digests from those commands:

```yaml
components:
  frontend:
    image: "123456789012.dkr.ecr.us-east-1.amazonaws.com/securecicd/frontend@sha256:REPLACE"
  backend:
    image: "123456789012.dkr.ecr.us-east-1.amazonaws.com/securecicd/backend@sha256:REPLACE"
  redis:
    image: "docker.io/library/redis@sha256:REPLACE"
```

If Docker prints Redis as `redis@sha256:...`, expand its repository to
`docker.io/library/redis` for the policy's exact match. `sha256:REPLACE` is deliberately
invalid and will fail the policy gate until edited. Node roles (or Fargate execution
roles) need ECR pull permissions; the operator needs publish and Kubernetes permissions.

```bash
aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME" --alias securecicd-eks
kubectl --context securecicd-eks apply -f k8s/namespace.yaml
python3 -m pip install PyYAML==6.0.2
make test
make check
make deploy CONTEXT=securecicd-eks VALUES=build/eks-values.yaml
kubectl --context securecicd-eks -n securecicd port-forward svc/frontend 8080:8080
```

The chart uses internal Services and no public ingress. Adapt NetworkPolicies to
your CNI and DNS configuration. This demo is not an EKS provisioning module.

## IRSA extension

The voting app calls Redis and needs **no AWS API permissions**. IRSA is therefore
left unconfigured. For an extension that accesses AWS services, create an EKS OIDC
provider and a least-privilege IAM role trusted for the service account subject
`system:serviceaccount:securecicd:voting-app` and audience `sts.amazonaws.com`.
Set the chart's `serviceAccount.annotations.eks.amazonaws.com/role-arn` to that role.
Use a supported AWS SDK and its default credential chain. See
[AWS IRSA documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).

The demo shares one service account; split it by workload before granting real
permissions. Permit the needed STS/service endpoints in egress rules. IRSA authorizes
Pod AWS API calls; it is separate from image-pull permissions and a future GitHub
Actions OIDC deployment role. No cloud deployment workflow is enabled here.

Cleanup is operator-managed: remove only this demo's namespace and ECR repositories
when no longer needed. Do not delete a shared EKS cluster as part of demo cleanup.
