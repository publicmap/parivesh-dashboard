#!/bin/bash
set -uo pipefail

ACTION=${1:?usage: proxy.sh start|stop}
ZONE=${ZONE:-asia-south1-a}
PORT=${PORT:-8080}
PROXY_VERSION=${PROXY_VERSION:-1.2.0}

gcloud auth activate-service-account --key-file=<(echo "$GCP_AUTH" | base64 -d) --quiet || exit 1

start() {
  local stamp name tag fw ip
  stamp=$(date +%s)
  name="proxy-instance-$stamp"
  tag="proxy-tag-$stamp"
  fw="tcp-rule-$stamp"

  echo "instance_name=$name" >> "$GITHUB_OUTPUT"
  echo "fw_rule_name=$fw" >> "$GITHUB_OUTPUT"

  sed -e "s/<VERSION>/$PROXY_VERSION/g" -e "s/<PORT>/$PORT/g" \
      -e "s|<BASIC_AUTH>|-basic-auth \"$PROXY_AUTH\"|g" scripts/proxy-startup.sh.tmpl > startup.sh

  gcloud compute instances create "$name" \
    --project="$GCP_PROJECT" --zone="$ZONE" --machine-type=e2-small \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --provisioning-model=STANDARD --maintenance-policy=MIGRATE \
    --max-run-duration=86400s --instance-termination-action=DELETE \
    --tags="$tag" \
    --create-disk=auto-delete=yes,boot=yes,size=10,type=pd-balanced,image-family=ubuntu-2204-lts,image-project=ubuntu-os-cloud \
    --metadata-from-file startup-script=startup.sh || exit 1

  ip=$(gcloud compute instances describe "$name" --project="$GCP_PROJECT" --zone="$ZONE" \
    --format='value(networkInterfaces[0].accessConfigs[0].natIP)')
  [ -n "$ip" ] || exit 1
  echo "ip_address=$ip" >> "$GITHUB_OUTPUT"

  gcloud compute firewall-rules create "$fw" --project="$GCP_PROJECT" \
    --allow=tcp:"$PORT" --direction=INGRESS --target-tags="$tag" || exit 1

  for i in $(seq 1 60); do
    if nc -z "$ip" "$PORT"; then echo "proxy up at $ip:$PORT"; return 0; fi
    sleep 5
  done
  echo "proxy did not come up" >&2
  exit 1
}

stop() {
  [ -n "${INSTANCE_NAME:-}" ] && gcloud compute instances delete "$INSTANCE_NAME" \
    --project="$GCP_PROJECT" --zone="$ZONE" --quiet || echo "instance already gone"
  [ -n "${FW_RULE_NAME:-}" ] && gcloud compute firewall-rules delete "$FW_RULE_NAME" \
    --project="$GCP_PROJECT" --quiet || echo "firewall rule already gone"
  exit 0
}

"$ACTION"
