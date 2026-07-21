/**
 * Sample Node service for the Docker Practical Lab.
 *
 * Ships with a real TypeScript build step and a small production dependency
 * so the later "image diet" exercise has something to strip (devDependencies)
 * and something that must remain (runtime deps + dist/).
 */

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { nanoid } from "nanoid";

const port = Number.parseInt(process.env.PORT ?? "8212", 10);
const startedAt = Date.now();
const instanceId = nanoid(8);
// Keep request bodies small; this is a teaching API, not a file upload service.
const maxBodyBytes = 64 * 1024;

type Json = Record<string, unknown>;

function sendJson(res: ServerResponse, status: number, payload: Json): void {
  const body = `${JSON.stringify(payload, null, 2)}\n`;
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let total = 0;
    req.on("data", (chunk: Buffer) => {
      total += chunk.length;
      if (total > maxBodyBytes) {
        reject(new Error(`request body exceeds ${maxBodyBytes} bytes`));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

const server = createServer(async (req, res) => {
  const method = req.method ?? "GET";
  const url = new URL(req.url ?? "/", `http://127.0.0.1:${port}`);
  const path = url.pathname.replace(/\/$/, "") || "/";

  if (method === "GET" && path === "/health") {
    sendJson(res, 200, { status: "ok", instance: instanceId });
    return;
  }

  if (method === "GET" && path === "/") {
    sendJson(res, 200, {
      service: "node-app",
      message: "Sample Node app for the Docker Practical Lab",
      instance: instanceId,
      uptime_seconds: Math.round((Date.now() - startedAt) / 1000),
      endpoints: {
        "GET /health": "liveness",
        "GET /greet?name=Ada": "small runtime dependency in action (nanoid + greeting)",
        "POST /echo": 'JSON echo: {"message":"hello"}',
      },
      build_note:
        "Production start uses dist/server.js from `npm run build`. DevDependencies must not ship in the final image.",
    });
    return;
  }

  if (method === "GET" && path === "/greet") {
    const name = url.searchParams.get("name")?.trim() || "friend";
    sendJson(res, 200, {
      greeting: `Hello, ${name}.`,
      request_id: nanoid(),
      instance: instanceId,
    });
    return;
  }

  if (method === "POST" && path === "/echo") {
    try {
      const raw = await readBody(req);
      const parsed = raw ? (JSON.parse(raw) as Json) : {};
      if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
        sendJson(res, 400, { error: "JSON body must be an object" });
        return;
      }
      sendJson(res, 200, {
        echoed: parsed,
        request_id: nanoid(),
        instance: instanceId,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "invalid request body";
      const status = message.includes("exceeds") ? 413 : 400;
      sendJson(res, status, {
        error: message.includes("JSON") || message.includes("exceeds")
          ? message
          : "body must be valid JSON",
      });
    }
    return;
  }

  sendJson(res, 404, { error: "not found", path });
});

server.listen(port, "0.0.0.0", () => {
  console.log(`node-app listening on 0.0.0.0:${port}`);
  console.log(`instance ${instanceId}`);
  console.log(`Try: curl http://127.0.0.1:${port}/health`);
});
