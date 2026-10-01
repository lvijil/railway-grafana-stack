#!/bin/sh
set -eu

# Railway variables override Docker ENV values. Apply the ViaTrack profile at
# process startup so an old template value cannot restore the large defaults.
telemetry_enabled="${TELEMETRY_ENABLED:-${TELEMETRY_INGEST_ENABLED:-false}}"

if [ "$telemetry_enabled" = "true" ]; then
  export GOMEMLIMIT="${GRAFANA_GOMEMLIMIT:-256MiB}"
  export GOGC="${GRAFANA_GOGC:-50}"
else
  # Grafana itself has a large base RSS even with no queries. Replace it with
  # BusyBox netcat's tiny HTTP responder while observability is intentionally
  # disabled. Set TELEMETRY_ENABLED=true and redeploy to restore Grafana.
  idle_root=/tmp/grafana-idle
  mkdir -p "$idle_root"
  cat > "$idle_root/respond.sh" <<'EOF'
#!/bin/sh
body='{"status":"disabled","message":"Establece TELEMETRY_ENABLED=true y redespliega Grafana para abrir los paneles."}'
printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s' "${#body}" "$body"
EOF
  chmod 500 "$idle_root/respond.sh"
  exec nc -lk -p "${PORT:-3000}" -e "$idle_root/respond.sh"
fi

export GOMAXPROCS="${GRAFANA_GOMAXPROCS:-1}"

# ViaTrack uses Grafana's built-in Prometheus, Loki and Tempo data sources.
# Ignore legacy plugin variables inherited from the original Railway template.
unset GF_INSTALL_PLUGINS
unset GF_PLUGINS_PREINSTALL
unset GF_PLUGINS_PREINSTALL_SYNC

exec /run.sh "$@"
