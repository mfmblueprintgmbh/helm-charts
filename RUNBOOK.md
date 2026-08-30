# Runbook

Everything here is copy and paste. Budget about forty minutes end to end, most of it waiting
for a container image to push.

---

## Step 0. Decide two things (30 seconds)

**GitHub org slug.** The repo defaults to an org called `bluebill`. If that name is taken,
pick another and run the rebrand script before you commit anything:

```bash
./rebrand.sh <your-org> mfmblueprintgmbh.github.io/helm-charts ai.bluebill.io
git diff        # review, should only touch URLs
```

**Chart hostname.** Either works:

| Option | URL customers type | Setup |
| ------ | ------------------ | ----- |
| Custom domain | `https://mfmblueprintgmbh.github.io/helm-charts` | One CNAME record, better branding |
| Default | `https://<org>.github.io/helm-charts` | Nothing, works immediately |

If you go with the default, run:

```bash
./rebrand.sh <your-org> <your-org>.github.io/helm-charts ai.bluebill.io
```

---

## Step 1. Create the org and repo (you, in a browser)

1. github.com/organizations/new, free plan, name it with your slug.
2. New repository inside it, named `helm-charts`. Public. Do not initialise with a README.

Public is required: Helm has to fetch the index without credentials, and GitHub Pages on
private repos needs a paid plan.

---

## Step 2. Push (one commit, clean history)

The repo in this bundle is already a git repository with a single commit authored by
`Bluebill <dev@bluebill.io>`. There is no upstream history and no vendor email in it. Just
point it at your remote:

```bash
cd bb
git remote add origin git@github.com:<your-org>/helm-charts.git
git push -u origin main
```

If you rebranded in step 0, amend first so it stays a single commit:

```bash
git add -A && git commit --amend --no-edit
```

---

## Step 3. Turn on Pages

Repo Settings, Pages. Source: deploy from branch, `gh-pages`, root.

The `gh-pages` branch does not exist yet. It is created by the release workflow the first
time it runs, which is on your first push to `main`. So: push, wait for the Actions run to go
green, then set Pages.

For the custom domain, add the CNAME in the same screen and create the DNS record:

```
charts   CNAME   <your-org>.github.io
```

Tick "Enforce HTTPS" once the certificate provisions, which takes a few minutes.

---

## Step 4. Mirror the container image

This is the one hard blocker. The chart pulls `ghcr.io/<your-org>/kube-service-selectors:0.1.0`
and that path is empty until you push to it. Without this the install fails immediately with
ImagePullBackOff.

Fastest route, on any machine with Docker:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <your-github-user> --password-stdin

docker pull --platform linux/amd64 hystax/kube-service-selectors:0.1.0
docker tag hystax/kube-service-selectors:0.1.0 ghcr.io/<your-org>/kube-service-selectors:0.1.0
docker push ghcr.io/<your-org>/kube-service-selectors:0.1.0
```

The token needs `write:packages`. Create it at github.com/settings/tokens.

Then, and this is easy to forget: go to the org's Packages tab, open the package, Package
settings, and change visibility to **Public**. If it stays private, every customer needs an
imagePullSecret and the guide gets an extra step.

Caveat on re-tagging: `docker history` on the result still shows the upstream build, and the
image config may carry upstream labels. Check with:

```bash
docker inspect ghcr.io/<your-org>/kube-service-selectors:0.1.0 | grep -i -e hystax -e optscale
```

If that returns anything and it bothers you, rebuild from source instead. It is a small
Python service. For an AI scale up customer, re-tagging is almost certainly fine.

---

## Step 5. Validate before the guide leaves your hands

On any machine with Helm 3:

```bash
helm repo add bluebill https://mfmblueprintgmbh.github.io/helm-charts
helm repo update
helm search repo bluebill                    # the chart should be listed

helm template test bluebill/kube-cost-metrics-collector \
  --namespace bluebill \
  --set prometheus.server.dataSourceId=test \
  --set prometheus.server.username=test \
  --set prometheus.server.password=test > /tmp/rendered.yaml

grep -i -e hystax -e optscale /tmp/rendered.yaml    # must print nothing
grep -A5 basic_auth /tmp/rendered.yaml              # must show username + password_file
grep -i image: /tmp/rendered.yaml                   # every image must be ghcr.io or a neutral upstream
```

The middle check is the important one. If `basic_auth` is missing, remote write will
authenticate against nothing and the customer will see an empty dashboard with no error that
points at the cause.

Then do one real install against a throwaway data source, on kind, minikube or the Hetzner
cluster:

```bash
helm install test bluebill/kube-cost-metrics-collector \
  --namespace bluebill --create-namespace --values values.local.yaml

kubectl -n bluebill get pods
kubectl -n bluebill logs deploy/test-prometheus-server -f | grep remote
```

Silence in that log means it is working. Repeated `Failed to send batch` means the endpoint,
the certificate or the credentials are wrong. Clean up with
`helm uninstall test -n bluebill && kubectl delete ns bluebill`.

---

## Step 6. Send the guide

`docs/kubernetes-connection-guide.md` is written to go to the customer as is. Delete the
italic note at the top and check the endpoint hostname matches what their data source
actually points at.

---

## Still open with the vendor

Not blocking for tomorrow, but worth an answer:

- Which images in the chart come from their registry. If the selectors exporter is not the
  only one, step 4 has to be repeated for each.
- Whether the Kubernetes Integration screen in your instance can emit your chart repo,
  namespace and endpoint. If it cannot, a customer who clicks that button in the product
  reads their version regardless of what you publish by hand.
- Who watches upstream for chart changes and tells you.
