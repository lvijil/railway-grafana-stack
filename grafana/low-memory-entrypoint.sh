#!/bin/sh
set -eu

# Use ViaTrack-specific variables so old template values in Railway cannot
# silently replace the resource profile baked into this service.
export GOMEMLIMIT="${GRAFANA_GOMEMLIMIT:-256MiB}"
export GOGC="${GRAFANA_GOGC:-50}"
export GOMAXPROCS="${GRAFANA_GOMAXPROCS:-1}"

# ViaTrack uses only Grafana's built-in panels and data sources. The original
# Railway template installed four legacy plugins during every container start.
unset GF_INSTALL_PLUGINS
unset GF_PLUGINS_PREINSTALL
unset GF_PLUGINS_PREINSTALL_SYNC

exec /run.sh "$@"
