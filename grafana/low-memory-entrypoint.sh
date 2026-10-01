#!/bin/sh
set -eu

# Railway variables override Docker ENV values. Apply the ViaTrack profile at
# process startup so an old template value cannot restore the large defaults.
if [ "${TELEMETRY_INGEST_ENABLED:-false}" = "true" ]; then
  export GOMEMLIMIT="${GRAFANA_GOMEMLIMIT:-256MiB}"
  export GOGC="${GRAFANA_GOGC:-50}"
else
  # Keep Grafana usable for a quick review of historical data while telemetry
  # is off, without retaining the caches and heap intended for active tracing.
  export GOMEMLIMIT="${GRAFANA_IDLE_GOMEMLIMIT:-128MiB}"
  export GOGC="${GRAFANA_IDLE_GOGC:-25}"
  export GF_QUERY_CONCURRENT_QUERY_LIMIT=1
  export GF_DATASOURCES_CONCURRENT_QUERY_COUNT=1
  export GF_DATAPROXY_MAX_IDLE_CONNECTIONS=2
fi

export GOMAXPROCS="${GRAFANA_GOMAXPROCS:-1}"

# ViaTrack uses Grafana's built-in Prometheus, Loki and Tempo data sources.
# Ignore legacy plugin variables inherited from the original Railway template.
unset GF_INSTALL_PLUGINS
unset GF_PLUGINS_PREINSTALL
unset GF_PLUGINS_PREINSTALL_SYNC

exec /run.sh "$@"
