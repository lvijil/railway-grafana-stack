#!/bin/sh
set -eu

: "${METRICS_SECRET:?METRICS_SECRET is required}"
: "${PROMETHEUS_SCRAPE_CONFIGS:?PROMETHEUS_SCRAPE_CONFIGS is required}"

printf '%s' "$METRICS_SECRET" > /tmp/metrics-secret
chmod 600 /tmp/metrics-secret

cat /etc/prometheus/prom.yml > /tmp/prometheus.yml
printf '\n' >> /tmp/prometheus.yml
printf '%s\n' "$PROMETHEUS_SCRAPE_CONFIGS" | sed 's/^/  /' >> /tmp/prometheus.yml

/bin/promtool check config /tmp/prometheus.yml

exec /bin/prometheus \
  --config.file=/tmp/prometheus.yml \
  --storage.tsdb.path=/prometheus
