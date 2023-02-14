#!/bin/sh
app=kubectl-build

if [ -n "$MY_POD_NAME" ] && [ -n "$MY_POD_UID" ]; then
  owner="$(cat <<EOT
{
  "apiVersion": "v1",
  "kind": "Pod",
  "name": "$MY_POD_NAME",
  "uid": "$MY_POD_UID"
}
EOT
)"
else
  owner=""
fi

trap 'exit 0' SIGINT
while true; do
  today="$(date +%Y-%m-%d)"
  metadata_overrides="$(cat <<EOT
{
  "labels": {
    "app": "$app",
    "build-date": "$today"
   }, 
   "ownerReferences": [$owner]
}
EOT
  )"

  (set -x; make pull)

  echo "+ make changed" >&2
  for submodule in $(make list-changed); do
    make $submodule \
      KUBECTL_BUILD_KEEP_POD=true \
      KUBECTL_BUILD_METADATA_OVERRIDES="$metadata_overrides"
  done

  (
    set -x
    make push
    kubectl delete pod --wait=false -l "app=$app,build-date!=$today"
    sleep ${SYNC_INTERVAL:-1m}
  )
done
