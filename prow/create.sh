#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

NAMESPACE=${NAMESPACE:-default}
WORKER_NS=${WORKER_NS:-test-pods}

# create prow namespace
kubectl create namespace "${NAMESPACE}" || echo Skipping

# create test-pods namespace
kubectl create namespace "${WORKER_NS}" || echo Skipping

# create configmaps
kubectl -n "${NAMESPACE}" create cm config || echo Skipping
kubectl -n "${NAMESPACE}" create cm plugins || echo Skipping

# create secrets
kubectl -n "${NAMESPACE}" create secret generic hmac-token --from-file=hmac=secrets/github-hmac-secret || echo Skipping
kubectl -n "${NAMESPACE}" create secret generic cookie --from-file=secret=secrets/cookie-secret || echo Skipping
kubectl -n "${NAMESPACE}" create secret generic oauth-token --from-file=oauth=secrets/github-token || echo Skipping

kubectl -n "${WORKER_NS}" create secret generic github-token --from-file=github-token=secrets/github-token || echo Skipping
kubectl -n "${WORKER_NS}" create secret generic gcs-credentials --from-file=service-account.json=secrets/gcs-credentials.json || echo Skipping

# creates service account including secret holding kubeconfig (for auto-updating prow config on merged PRs)
./"${DIR}"/setup-prow-deployer.sh

# creates secret with cluster credentials for e2e tests
kubectl create secret generic ike-cluster-credentials --from-literal=IKE_CLUSTER_USER="${IKE_CLUSTER_USER:-ike}" --from-literal=IKE_CLUSTER_PWD="${IKE_CLUSTER_PWD:-letmein}" -n "${WORKER_NS}"

# enables privileged container builds
oc adm policy add-scc-to-user privileged -z default -n "${WORKER_NS}" || echo "Not Openshift. Skipping"

sleep 10

# deploy prow
./"${DIR}"/update.sh

