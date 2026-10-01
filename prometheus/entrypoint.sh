#!/bin/sh
set -eu

telemetry_enabled="${TELEMETRY_ENABLED:-false}"

if [ "$telemetry_enabled" != "true" ]; then
  # Prometheus loads its TSDB and keeps a substantial base RSS even without
  # targets. Do not start it while telemetry is intentionally disabled.
  idle_root=/tmp/prometheus-idle
  mkdir -p "$idle_root/-"
  cat > "$idle_root/index.html" <<'EOF'
<!doctype html><html lang="es"><meta charset="utf-8"><title>Telemetría apagada</title><body><h1>Telemetría apagada</h1><p>Establece TELEMETRY_ENABLED=true y redespliega Prometheus para consultar métricas.</p></body></html>
EOF
  printf 'ready\n' > "$idle_root/-/ready"
  printf 'healthy\n' > "$idle_root/-/healthy"
  printf 'disabled\n' > "$idle_root/health"
  printf '# telemetry disabled\n' > "$idle_root/metrics"
  exec busybox httpd -f -p "${PORT:-9090}" -h "$idle_root"
fi

: "${METRICS_SECRET:?METRICS_SECRET is required when TELEMETRY_ENABLED=true}"
: "${PROMETHEUS_SCRAPE_CONFIGS:?PROMETHEUS_SCRAPE_CONFIGS is required when TELEMETRY_ENABLED=true}"
: "${FABONI_METRICS_TARGET:=faboni.uviat.com}"

export GOMEMLIMIT="${PROMETHEUS_GOMEMLIMIT:-256MiB}"
export GOGC="${PROMETHEUS_GOGC:-50}"
export GOMAXPROCS="${PROMETHEUS_GOMAXPROCS:-1}"

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
  --storage.tsdb.path=/prometheus \
  --query.max-concurrency="${PROMETHEUS_QUERY_MAX_CONCURRENCY:-4}" \
  --query.max-samples="${PROMETHEUS_QUERY_MAX_SAMPLES:-500000}"
