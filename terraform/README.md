# EKS Cluster with Karpenter

Terraform setup for an EKS cluster with Karpenter autoscaling. Supports x86 and Graviton (arm64) instances, Spot and On-Demand.

## What Gets Created

- A dedicated **VPC** with public/private subnets across 3 AZs
- An **EKS 1.32** cluster with a small x86 system node group (`m7i.large`) for running cluster components
- **Karpenter** configured to provision workload nodes on-demand — both architectures, Spot preferred

## Quick Start

```bash
terraform init
terraform plan
terraform apply    # ~15-20 minutes

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name startup-eks

# Verify
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
kubectl get nodepools
kubectl get ec2nodeclasses
```

## Running on x86 vs Graviton

Use `nodeSelector` to pick the architecture. Karpenter handles the rest.

**x86 (Intel/AMD):**

```bash
kubectl apply -f examples/x86-deployment.yaml
```

```yaml
spec:
  nodeSelector:
    kubernetes.io/arch: amd64
```

**Graviton (arm64):**

```bash
kubectl apply -f examples/graviton-deployment.yaml
```

```yaml
spec:
  nodeSelector:
    kubernetes.io/arch: arm64
```

**No preference (cheapest wins):**

```bash
kubectl apply -f examples/multi-arch-deployment.yaml
```

Without a `nodeSelector`, Karpenter picks the cheapest option from the full pool — this is where Spot + Graviton savings are maximized.

## Controlling Spot vs On-Demand

The NodePool allows both capacity types. Karpenter prefers Spot by default since it's cheaper.

To force On-Demand for a specific workload, use a `nodeSelector`:

```yaml
spec:
  nodeSelector:
    karpenter.sh/capacity-type: on-demand
```

### Using Taints and Tolerations

For stricter control, you can create separate NodePools with taints. For example, a Spot-only pool could add a taint like `karpenter.sh/capacity-type=spot:NoSchedule`, so only pods that explicitly tolerate Spot will land there. This is useful when you want to guarantee that critical workloads (databases, payment services) never run on Spot, while batch/background jobs always do.

Example pod spec tolerating Spot:

```yaml
spec:
  tolerations:
    - key: karpenter.sh/capacity-type
      operator: Equal
      value: spot
      effect: NoSchedule
  nodeSelector:
    karpenter.sh/capacity-type: spot
```

This gives teams full control without changing the default behavior for everyone else.

## How Karpenter Resources Are Managed

The Karpenter CRDs (NodePool, EC2NodeClass) live in `karpenter-resources/templates/` as plain YAML files, packaged as a minimal local Helm chart.

**Why a Helm chart instead of inline Terraform?**

Defining Kubernetes manifests inside Terraform with `yamlencode()` or providers like `kubectl_manifest` mixes infrastructure provisioning with application-level configuration. It's hard to read, hard to diff, and adds provider dependencies. A local Helm chart keeps the YAML clean and readable while still being deployed in the same `terraform apply`.

**Adding new resources** is just dropping a YAML file into `karpenter-resources/templates/` — no Terraform changes needed.

**In a real project**, you'd likely manage these manifests through a GitOps tool like **ArgoCD** or **Flux** instead of Terraform. Terraform would provision the cluster and install Karpenter, and ArgoCD would own the NodePool/EC2NodeClass lifecycle — giving teams self-service control over their node configurations without touching infrastructure code.

## Project Structure

```
terraform/
├── versions.tf                     # Terraform + provider versions
├── main.tf                         # VPC + eks-karpenter module call
├── variables.tf                    # Input variables
├── outputs.tf                      # Outputs
├── karpenter-resources/            # Karpenter CRDs (local Helm chart)
│   ├── Chart.yaml
│   └── templates/
│       ├── nodeclass.yaml
│       └── nodepool.yaml
├── modules/
│   └── eks-karpenter/              # Reusable EKS + Karpenter module
│       ├── main.tf                 #   EKS cluster, addons, system nodes
│       ├── karpenter.tf            #   Karpenter IAM, controller, resource deployment
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
└── examples/
    ├── x86-deployment.yaml
    ├── graviton-deployment.yaml
    └── multi-arch-deployment.yaml
```

## Design Decisions

**x86 system nodes** — The system node group runs CoreDNS, kube-proxy, vpc-cni, and Karpenter itself. x86 (`m7i.large`) is the safest default for these components. Graviton is available for workload nodes through Karpenter.

**Single NodePool for both architectures** — Giving Karpenter access to both x86 and arm64 maximizes the instance pool for bin-packing and Spot availability. Developers choose their architecture via `nodeSelector`.

**Spot + On-Demand in one pool** — Karpenter prefers Spot for cost savings and falls back to On-Demand when Spot isn't available. Critical workloads can force On-Demand via `nodeSelector` or taints.

**Aggressive consolidation** — `WhenEmptyOrUnderutilized` with a 1-minute cooldown keeps costs low by actively repacking or removing underused nodes.

**Single NAT gateway** — Cost-effective for a POC. For production, use one NAT gateway per AZ for high availability.

## Cleanup

```bash
kubectl delete deployments --all
kubectl get nodes -w              # wait for Karpenter to drain nodes
terraform destroy
```
