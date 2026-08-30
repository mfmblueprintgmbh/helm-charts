Kubernetes cost metrics collector
====

Ready to deploy set of components for Kubernetes cost management and FinOps in Bluebill.

Components
- [Prometheus](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus), running in agent mode
  - [kube-state-metrics](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics)
  - [prometheus-node-exporter](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-node-exporter)
  - [prometheus-pushgateway](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-pushgateway)
- kube-service-selectors

Prometheus runs with `--enable-feature=agent` and no local persistent volume, so nothing is
stored in the cluster. Samples are streamed out over `remote_write` to Bluebill.

## Prerequisites
- Kubernetes 1.17+
- Helm 3+
- Outbound HTTPS from the cluster to the Bluebill endpoint
- A Kubernetes data source created in Bluebill, which yields a data source id, a username and a password

## Installation

One release per cluster.

```bash
helm repo add bluebill https://mfmblueprintgmbh.github.io/helm-charts
helm repo update

helm install kube-cost-metrics-collector bluebill/kube-cost-metrics-collector \
  --namespace bluebill \
  --create-namespace \
  --values values.local.yaml
```

with `values.local.yaml`:

```yaml
prometheus:
  server:
    dataSourceId: <data-source-id>
    username: <username>
    password: <password>
```

Passing the password with `--set` puts it into shell history and into the CI logs of
whoever runs it. A values file that is deleted afterwards is the better habit. The password
is stored in the cluster as a Kubernetes Secret either way.

## Upgrade

```bash
helm repo update
helm upgrade kube-cost-metrics-collector bluebill/kube-cost-metrics-collector \
  --namespace bluebill \
  --reuse-values
```

## Configuration

| Parameter | Description |
| --------- | ----------- |
| `prometheus.server.dataSourceId` | Kubernetes data source id from Bluebill |
| `prometheus.server.username` | Username set when the data source was created |
| `prometheus.server.password` | Password set when the data source was created |
| `prometheus.server.remote_write[0].url` | Ingest endpoint. Defaults to the Bluebill production endpoint |
| `prometheus.server.caFile` | CA certificate for the ingest endpoint. See TLS below |
| `prometheus.kubeStateMetrics.enabled` | Set to false if kube-state-metrics already runs in the cluster |
| `prometheus.prometheus-node-exporter.enabled` | Set to false if a node exporter already runs in the cluster |
| `prometheus.prometheus-pushgateway.enabled` | Set to false if a pushgateway already runs in the cluster |

Everything else is in [values.yaml](values.yaml), or run:

```bash
helm show values bluebill/kube-cost-metrics-collector
```

### The remote_write entry named `bluebill`

The templates look for the `remote_write` entry whose `name` is `bluebill` and inject the
basic auth block and the `Cloud-Account-Id` header into that entry only. Renaming it in
`values.yaml` without also editing `templates/_helpers.tpl` and
`templates/prometheus-server-cm.yaml` produces a chart that installs cleanly and then fails
authentication at runtime with no obvious cause. Additional `remote_write` targets can be
added freely under other names; they are passed through untouched.

### TLS

If `caFile` is not set, the chart configures `insecure_skip_verify: true` on the remote
write target. That works, but it means the agent will accept any certificate presented by
anything answering on that hostname. When the endpoint has a certificate from a public CA,
set `caFile` to the CA bundle so verification is on. When the endpoint is reached over plain
HTTP or by bare IP, remote write fails; the endpoint needs a real hostname and certificate.

## Verification

After install:

```bash
kubectl -n bluebill get pods
kubectl -n bluebill logs deploy/kube-cost-metrics-collector-prometheus-server -f | grep remote
```

Healthy output is quiet. Repeated `Failed to send batch, retrying` lines mean the endpoint,
the certificate or the credentials are wrong. Metrics take roughly an hour to appear in the
interface, so do not treat an empty first view as a failure.
