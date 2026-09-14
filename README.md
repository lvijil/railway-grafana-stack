# Grafana Stack on Railway

## ViaTrack telemetry gateway

The `telemetry-gateway` directory provides a small authenticated public ingress for
Loki pushes and OTLP/HTTP traces. Create one Railway service from this repository
with root directory `/telemetry-gateway` and a public
domain. Configure `OBSERVABILITY_INGEST_SECRET` (at least 32 characters), and share
the same value only with the applications that send telemetry. The internal
defaults expect Railway services named `loki` and `tempo`; override
`LOKI_PUSH_URL` or `TEMPO_OTLP_HTTP_URL` when those service names differ.

Gateway variables:

```text
OBSERVABILITY_INGEST_SECRET=<shared random value, at least 32 characters>
LOKI_PUSH_URL=http://loki.railway.internal:3100/loki/api/v1/push
TEMPO_OTLP_HTTP_URL=http://tempo.railway.internal:4318/v1/traces
```

ViaTrack Web variables, using the gateway public domain:

```text
SERVICE_NAME=viatrack-web
LOKI_PUSH_URL=https://<gateway-domain>/loki/api/v1/push
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://<gateway-domain>/v1/traces
OBSERVABILITY_INGEST_SECRET=<same shared value>
```

ViaTrack API variables:

```text
SERVICE_NAME=viatrack-api
LOKI_PUSH_URL=https://<gateway-domain>/loki/api/v1/push
OBSERVABILITY_INGEST_SECRET=<same shared value>
```

Grafana reads Loki and Tempo through its server-side proxy. The provisioned ViaTrack
dashboard includes recent correlated requests. Request, trace, tenant, and user IDs
remain JSON fields or Loki structured metadata; they are intentionally not metric
labels because their cardinality grows without bound.

The ViaTrack dashboard refreshes once per minute and caps its log panel to reduce
query pressure. Grafana is pinned to the supported `13.2.1` OSS image and uses a
small-instance profile with `GOMEMLIMIT=256MiB`,
`GOGC=50`, one Go scheduler thread, bounded query concurrency and no alerting,
Grafana Live, query history, public dashboards or legacy plugins. Tempo defaults
to `GOMEMLIMIT=320MiB`, `GOGC=75`, and both services promptly release unused Go
memory. `GOMEMLIMIT` is a soft Go runtime target rather than a hard container
limit, so Railway can report more memory than this value. The image entrypoint
removes the obsolete plugin variables inherited from the original template and
applies the resource profile after Railway injects service variables.

The profile can be tuned without editing the image through
`GRAFANA_GOMEMLIMIT`, `GRAFANA_GOGC` and `GRAFANA_GOMAXPROCS`. Do not use the
generic `GOMEMLIMIT`, `GOGC`, `GOMAXPROCS`, `GF_INSTALL_PLUGINS` or
`GF_PLUGINS_PREINSTALL` variables in this service; the entrypoint intentionally
ignores them.

Grafana automatically moves folders and dashboards to Unified Storage. This
image explicitly enables the folder and dashboard migrations so both resource
kinds are registered consistently, limits the SQLite migration cache to 32 MiB
instead of its 1 GB default, and uses the Parquet buffer to avoid SQLite lock
contention. The ViaTrack dashboard is provisioned in `General` and configured as
the home dashboard, so loading it does not depend on a separately persisted
folder resource.

Prometheus scrapes Grafana once per minute over Railway's private network. Use
`process_resident_memory_bytes{job="grafana"}` for the physical memory held by
the Grafana process and `go_memstats_heap_alloc_bytes{job="grafana"}` for its Go
heap. A large difference indicates memory outside the live heap or Linux page
cache rather than retained dashboard data.

Tempo uses only OTLP/HTTP, which is the protocol exposed by the telemetry gateway.
Its small-instance profile limits search concurrency and live block size, disables
per-span debug logging and anonymous usage reporting, reduces the default backend
worker queue and search buffers, and keeps Tempo's standard trace retention unchanged.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template/8TLSQD?referralCode=IFlm92)

## What is this template

This template deploys a complete Grafana observability stack on Railway with just one click! The stack includes four integrated services:

- **Grafana**: The leading open-source analytics and monitoring solution
- **Loki**: A horizontally-scalable, highly-available log aggregation system
- **Prometheus**: A powerful metrics collection and alerting system
- **Tempo**: A high-scale distributed tracing backend

This template is perfect for teams who need a comprehensive observability solution for their railway project without the hassle of manual configuration and infrastructure management.

### Key Features

- **Pre-configured Integration**: _All services come pre-connected_, so Grafana is ready to query your data immediately.
- **Persistent Storage**: All four services use Railway volumes to ensure your data, dashboards, and configurations persist between updates and deploys.
- **Version Control**: Pin specific Docker image versions for each service using environment variables.
- **Customizable**: Fork the repository to customize configuration files for any service. You can take full control and edit anything you'd need to as you scale.
- **One-Click Deploy**: Get a complete Grafana-based observability stack running in minutes.

## Quick Start Guide

1. Click the "Deploy on Railway" button at the top of this page
2. Enter your desired Grafana admin username in the `GF_SECURITY_ADMIN_USER` variable
3. Leave all other variables at their defaults (or customize as needed)
4. Wait for your stack to deploy (this typically takes 3-5 minutes)
5. Navigate to the Grafana URL provided by Railway
6. Log in with your admin username and the auto-generated password found in the `GF_SECURITY_ADMIN_PASSWORD` environment variable
7. Hook up your applications to the datasources.
8. Create dashboards, alerts, and explore your data in Grafana!

## Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GF_SECURITY_ADMIN_USER` | Username for the Grafana admin account | Required input |
| `GF_SECURITY_ADMIN_PASSWORD` | Password for the Grafana admin account | Auto-generated secure string |
| `GF_DEFAULT_INSTANCE_NAME` | Name of your Grafana instance | `Grafana on Railway` |
| `GRAFANA_GOMEMLIMIT` | Soft Go runtime memory target for the dedicated Grafana process | `256MiB` |
| `GRAFANA_GOGC` | Garbage collection frequency; lower values trade CPU for memory | `50` |
| `GRAFANA_GOMAXPROCS` | Maximum Go scheduler threads for this low-traffic instance | `1` |

### Internal Service URLs

The Grafana service exposes these environment variables that you can reference in your other Railway applications to easily send data to your observability stack:

| Variable | Description | Usage |
|----------|-------------|-------|
| `LOKI_INTERNAL_URL` | Internal URL for the Loki service | Use in your applications to send logs to and query Loki |
| `PROMETHEUS_INTERNAL_URL` | Internal URL for the Prometheus service | Use in your applications to send metrics to and query Prometheus |
| `TEMPO_INTERNAL_URL` | Internal URL for the Tempo service | Use in your applications to query Tempo |

These variables make it easy to configure your other Railway services to send telemetry data to your observability stack.

Tempo also exposes a few variables to make it easier to push tracing information to the service using either HTTP or GRPC

| Variable | Description | Usage |
|----------|-------------|-------|
| `INTERNAL_HTTP_INGEST` | Internal HTTP ingest server URL for Tempo | Use in your applications to send traces to tempo via HTTP |
| `INTERNAL_GRPC_INGEST` | Internal GRPC ingest server URL for Tempo | Use in your applications to send traces to tempo via GRPC |

### Version Control

Loki, Prometheus and Tempo accept a `VERSION` build variable in Railway:

- **Loki Service**: Set `VERSION` to control the Loki Docker image tag
- **Prometheus Service**: Set `VERSION` to control the Prometheus Docker image tag
- **Tempo Service**: Set `VERSION` to control the Tempo Docker image tag

Grafana is pinned directly in `grafana/dockerfile` so a stale Railway variable
cannot restore an unsupported image. Current versions:

Examples:
- Grafana: `13.2.1`
- Loki: `VERSION=3.4.2`
- Prometheus: `VERSION=v3.2.1`
- Tempo: `VERSION=2.9.0`

This allows you to update each component independently as needed.

> **⚠️ Note on Tempo v2.10.0**: There is a known issue with Tempo v2.10.0 where the `compactor` configuration block is not recognized, causing startup failures. This template is pinned to v2.9.0 until this issue is resolved in a future release.

## Project Structure & Services

This template deploys four interconnected services:

### Grafana
- The central visualization and dashboarding platform
- Pre-configured with connections to all other services
- Persistent volume for storing dashboards, users, and configurations
- Comes with useful plugins pre-installed
- Exposes internal URLs for other Railway services to connect to Loki, Prometheus, and Tempo

### Prometheus
- Time-series database for metrics collection
- Configured with sensible defaults for monitoring
- Persistent volume for metrics data

#### Dynamic scrape targets

The Prometheus service reads additional scrape jobs from Railway variables at startup:

- `METRICS_SECRET`: bearer secret shared with monitored applications.
- `PROMETHEUS_SCRAPE_CONFIGS`: a multiline YAML list of Prometheus jobs, without the top-level `scrape_configs` key.

Example:

```yaml
- job_name: viatrack-api
  scheme: https
  metrics_path: /api/metrics
  authorization:
    type: Bearer
    credentials_file: /tmp/metrics-secret
  static_configs:
    - targets:
        - viatrack.uviat.com

- job_name: viatrack-web
  scheme: https
  metrics_path: /metrics
  authorization:
    type: Bearer
    credentials_file: /tmp/metrics-secret
  static_configs:
    - targets:
        - viatrack.uviat.com
```

The entrypoint indents the job list under `scrape_configs` and validates the generated configuration with `promtool` before starting Prometheus.

The Grafana image provisions the **ViaTrack · Operation and API** dashboard automatically. It includes availability, endpoint/method/status tables, throughput, HTTP responses, p95 HTTP and database latency, web proxy, authentication, email, cron, and current operational records.

### Loki
- Log aggregation system designed to be cost-effective
- Horizontally scalable architecture
- Persistent volume for log storage

### Tempo
- Distributed tracing system for tracking requests across services
- High-performance trace storage
- Persistent volume for trace data

All services are deployed using official Docker images and configured to work together seamlessly.

## Connecting Your Applications

### Using [Locomotive](https://railway.com/template/jP9r-f) for Loki

You can easily ingest *all* of your railway logs into Loki from *any* service using [Locomotive](https://railway.com/template/jP9r-f). Just spin up their template, drop in your Railway API key, the ID of the services you want to monitor, and a link to your new Loki instance and logs will start flowing! no code changes needed anywhere!

### Using OpenTelemetry libraries for Tempo 

Tempo is a bit different than both Prometheus and Loki in that exposes separate GRPC and HTTP servers on ports `:4317` and `:4318` respectively specifically for ingesting your tracing data or "spans".

When configuring your application to send traces to Tempo, please use one of the preconfigured variables in the Tempo service: `INTERNAL_HTTP_INGEST` or `INTERNAL_GRPC_INGEST`.

Another thing to note is that the ingest API endpoint for the HTTP server is `/v1/traces`. For a working example of this in a node.js express API, see `/examples/api/tracer.js` in our GitHub repository.

### Using otherwise standard observability tooling

To send data from your other Railway applications to this observability stack:

1. In your application's Railway service, add environment variables that reference the internal URLs:
   ```
   LOKI_URL=${{Grafana.LOKI_INTERNAL_URL}}
   PROMETHEUS_URL=${{Grafana.PROMETHEUS_INTERNAL_URL}}
   TEMPO_URL=${{Grafana.TEMPO_INTERNAL_URL}}
   ```
2. Configure your application's logging, metrics, or tracing libraries to use these URLs
3. Your application data will automatically appear in your Grafana dashboards

## Customizing Your Stack

To customize the configuration of Loki, Prometheus, or Tempo:

1. Fork the [GitHub repository](https://github.com/yourusername/grafana-railway-template)
2. Modify the configuration files in their respective directories
3. In Railway, disconnect the service you want to customize
4. Reconnect the service to your forked repository
5. Deploy the updated service

The pre-configured Grafana connections will continue to work with your customized services.

## Additional Resources

- [Locomotive: a loki transport for railway services](https://railway.com/template/jP9r-f)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Grafana Community Forums](https://community.grafana.com/)
- [Grafana Plugins Directory](https://grafana.com/grafana/plugins/)

---

Developed and maintained by [Mykal](https://mykal.codes). For issues or suggestions, please open an issue on the [GitHub repository](https://github.com/MykalMachon/grafana-stack-railway).
