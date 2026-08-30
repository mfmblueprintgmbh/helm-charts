# Bluebill Helm charts

Helm charts for connecting infrastructure to the Bluebill platform.

[Helm](https://helm.sh) must be installed to use these charts. Add the repo as follows:

```bash
helm repo add bluebill https://mfmblueprintgmbh.github.io/helm-charts
helm repo update
```

Then:

```bash
helm search repo bluebill
```

## Charts

| Chart | Purpose |
| ----- | ------- |
| `kube-cost-metrics-collector` | Collects Kubernetes resource metrics and forwards them to Bluebill. Install one release per cluster. |
| `kube-service-selectors` | Exports Kubernetes service selectors as Prometheus metrics. Pulled in automatically by the collector. |

Customer facing installation instructions are in [docs/kubernetes-connection-guide.md](docs/kubernetes-connection-guide.md).
