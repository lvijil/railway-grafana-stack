#!/bin/sh
set -eu

: "${METRICS_SECRET:?METRICS_SECRET is required}"
: "${PROMETHEUS_SCRAPE_CONFIGS:?PROMETHEUS_SCRAPE_CONFIGS is required}"
: "${FABONI_METRICS_TARGET:=faboni.uviat.com}"

printf '%s' "$METRICS_SECRET" > /tmp/metrics-secret
chmod 600 /tmp/metrics-secret

cat /etc/prometheus/prom.yml > /tmp/prometheus.yml
printf '\n' >> /tmp/prometheus.yml
printf '%s\n' "$PROMETHEUS_SCRAPE_CONFIGS" > /tmp/scrape-configs.yml

if ! grep -Eq 'job_name:.*faboni-api' /tmp/scrape-configs.yml; then
  cat >> /tmp/scrape-configs.yml <<EOF

- job_name: faboni-api
  scheme: https
  metrics_path: /api/metrics
  authorization:
    type: Bearer
    credentials_file: /tmp/metrics-secret
  static_configs:
    - targets:
        - ${FABONI_METRICS_TARGET}
EOF
fi

if ! grep -Eq 'job_name:.*faboni-web' /tmp/scrape-configs.yml; then
  cat >> /tmp/scrape-configs.yml <<EOF

- job_name: faboni-web
  scheme: https
  metrics_path: /metrics
  authorization:
    type: Bearer
    credentials_file: /tmp/metrics-secret
  static_configs:
    - targets:
        - ${FABONI_METRICS_TARGET}
EOF
fi

sed 's/^/  /' /tmp/scrape-configs.yml >> /tmp/prometheus.yml

/bin/promtool check config /tmp/prometheus.yml

exec /bin/prometheus \
  --config.file=/tmp/prometheus.yml \
  --storage.tsdb.path=/prometheus
