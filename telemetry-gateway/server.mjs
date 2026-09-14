import { createServer } from "node:http";
import { timingSafeEqual } from "node:crypto";

const port = Number.parseInt(process.env.PORT ?? "8080", 10);
const ingestSecret = process.env.OBSERVABILITY_INGEST_SECRET ?? "";
const maxBodyBytes = Number.parseInt(process.env.MAX_BODY_BYTES ?? "5242880", 10);
const routes = new Map([
  ["/loki/api/v1/push", process.env.LOKI_PUSH_URL ?? "http://loki.railway.internal:3100/loki/api/v1/push"],
  ["/v1/traces", process.env.TEMPO_OTLP_HTTP_URL ?? "http://tempo.railway.internal:4318/v1/traces"],
]);

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error("PORT debe ser un puerto valido");
}

if (ingestSecret.length < 32) {
  throw new Error("OBSERVABILITY_INGEST_SECRET debe tener al menos 32 caracteres");
}

for (const [path, target] of routes) {
  const url = new URL(target);
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error(`URL de destino invalida para ${path}`);
  }
}

function writeJson(response, statusCode, payload) {
  response.writeHead(statusCode, { "content-type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(payload));
}

function hasValidBearer(request) {
  const authorization = request.headers.authorization ?? "";
  const prefix = "Bearer ";
  if (!authorization.startsWith(prefix)) return false;

  const supplied = Buffer.from(authorization.slice(prefix.length), "utf8");
  const expected = Buffer.from(ingestSecret, "utf8");
  return supplied.length === expected.length && timingSafeEqual(supplied, expected);
}

async function readBody(request) {
  const contentLength = Number.parseInt(request.headers["content-length"] ?? "0", 10);
  if (Number.isFinite(contentLength) && contentLength > maxBodyBytes) {
    throw Object.assign(new Error("payload demasiado grande"), { statusCode: 413 });
  }

  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > maxBodyBytes) {
      throw Object.assign(new Error("payload demasiado grande"), { statusCode: 413 });
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

const server = createServer(async (request, response) => {
  const requestUrl = new URL(request.url ?? "/", "http://telemetry-gateway");

  if (request.method === "GET" && requestUrl.pathname === "/health") {
    return writeJson(response, 200, { status: "ok" });
  }

  const target = routes.get(requestUrl.pathname);
  if (request.method !== "POST" || !target) {
    return writeJson(response, 404, { error: "not_found" });
  }

  if (!hasValidBearer(request)) {
    return writeJson(response, 401, { error: "unauthorized" });
  }

  const startedAt = Date.now();
  try {
    const body = await readBody(request);
    const upstream = await fetch(target, {
      method: "POST",
      headers: {
        "content-type": request.headers["content-type"] ?? "application/json",
        ...(request.headers["content-encoding"]
          ? { "content-encoding": request.headers["content-encoding"] }
          : {}),
      },
      body,
      signal: AbortSignal.timeout(15_000),
    });

    const upstreamBody = Buffer.from(await upstream.arrayBuffer());
    response.writeHead(upstream.status, {
      "content-type": upstream.headers.get("content-type") ?? "text/plain; charset=utf-8",
    });
    response.end(upstreamBody);

    console.log(JSON.stringify({
      timestamp: new Date().toISOString(),
      level: "info",
      event: "telemetry_forwarded",
      path: requestUrl.pathname,
      statusCode: upstream.status,
      durationMs: Date.now() - startedAt,
      bytes: body.length,
    }));
  } catch (error) {
    const statusCode = Number.isInteger(error?.statusCode) ? error.statusCode : 502;
    console.error(JSON.stringify({
      timestamp: new Date().toISOString(),
      level: "error",
      event: "telemetry_forward_failed",
      path: requestUrl.pathname,
      statusCode,
      durationMs: Date.now() - startedAt,
      error: error instanceof Error ? error.message : "unknown_error",
    }));
    writeJson(response, statusCode, { error: statusCode === 413 ? "payload_too_large" : "upstream_unavailable" });
  }
});

server.listen(port, "::", () => {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level: "info",
    event: "telemetry_gateway_started",
    port,
  }));
});
