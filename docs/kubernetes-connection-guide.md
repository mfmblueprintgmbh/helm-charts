# Connecting a Kubernetes cluster to Bluebill

This guide is written to be sent to a customer as is. Replace the bracketed values before
sending, and delete this line.

## What gets installed

A Helm release in your cluster containing Prometheus in agent mode, kube-state-metrics, a
node exporter, a pushgateway and a small exporter that maps services to their selectors.
Prometheus runs without local storage: it scrapes resource usage metrics and streams them
straight out to Bluebill over HTTPS. Nothing is stored inside your cluster and no inbound
connection is required, only outbound HTTPS.

Install one release per cluster.

## Requirements

- Kubernetes 1.17 or later
- Helm 3
- Cluster admin rights for the install, since the chart creates a ClusterRole
- Outbound HTTPS from the cluster to `https://ai.bluebill.io`
- Roughly 1 vCPU and 2 GB of memory of headroom across the cluster, mostly for the Prometheus agent

## Step 1: create the data source

In Bluebill, go to Data Sources and add a Kubernetes source. You will be asked for a name, a
user and a password. Choose these yourself; they are credentials the cluster will use to push
metrics, not an account login. On save you receive a **data source id**. Keep the id, the
user and the password to hand for step 3.

## Step 2: add the chart repository

```bash
helm repo add bluebill https://mfmblueprintgmbh.github.io/helm-charts
helm repo update
```

## Step 3: install

Create a file called `bluebill-values.yaml`:

```yaml
prometheus:
  server:
    dataSourceId: <data-source-id>
    username: <user>
    password: <password>
```

Then:

```bash
helm install kube-cost-metrics-collector bluebill/kube-cost-metrics-collector \
  --namespace bluebill \
  --create-namespace \
  --values bluebill-values.yaml
```

Delete `bluebill-values.yaml` afterwards, or keep it in whatever secret store you already
use. The password is written into a Kubernetes Secret in the `bluebill` namespace as part of
the install.

## Step 4: check it is working

```bash
kubectl -n bluebill get pods
```

All pods should reach Running. Then:

```bash
kubectl -n bluebill logs deploy/kube-cost-metrics-collector-prometheus-server -f | grep remote
```

Silence is success. Metrics take about an hour to appear in the interface, so the cluster
will look empty at first even when everything is correct.

## If metrics do not arrive

| Symptom in the Prometheus agent log | Cause |
| ----------------------------------- | ----- |
| `server gave HTTP response to HTTPS client` | The endpoint URL is being reached over plain HTTP. Use the HTTPS hostname, not an IP address |
| `x509: certificate signed by unknown authority` | The cluster does not trust the endpoint certificate. Set `prometheus.server.caFile` to your CA bundle |
| `401` or `403` on remote write | The user or password does not match what was entered on the data source, or the data source id is wrong |
| `context deadline exceeded`, `i/o timeout` | Egress to the endpoint is blocked. Allow outbound 443 to `ai.bluebill.io` |

## Existing monitoring

If the cluster already runs kube-state-metrics, a node exporter or a pushgateway, the
duplicates can be switched off so the collector uses yours:

```yaml
prometheus:
  kubeStateMetrics:
    enabled: false
  prometheus-node-exporter:
    enabled: false
  prometheus-pushgateway:
    enabled: false
```

## Removing it

```bash
helm uninstall kube-cost-metrics-collector --namespace bluebill
kubectl delete namespace bluebill
```
