#!/bin/sh
set -eu

# Railway variables override Docker ENV values. Apply the ViaTrack profile at
# process startup so an old template value cannot restore the large defaults.
export GOMEMLIMIT="${GRAFANA_GOMEMLIMIT:-256MiB}"
export GOGC="${GRAFANA_GOGC:-50}"
export GOMAXPROCS="${GRAFANA_GOMAXPROCS:-1}"

# ViaTrack uses Grafana's built-in Prometheus, Loki and Tempo data sources.
# Ignore legacy plugin variables inherited from the original Railway template.
unset GF_INSTALL_PLUGINS
unset GF_PLUGINS_PREINSTALL
unset GF_PLUGINS_PREINSTALL_SYNC

exec /run.sh "$@"
