Kubernetes service selectors exporter
====
Exports Kubernetes service selectors as Prometheus metrics. Installed automatically as a
dependency of `kube-cost-metrics-collector`; it does not normally need to be installed on its own.

#### Configuration
Available options are in [values.yaml](values.yaml). Alternatively run
```bash
helm show values bluebill/kube-service-selectors
```
