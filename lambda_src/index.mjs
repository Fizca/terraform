import { MongoClient } from "mongodb";
import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm";

const PROXY_SECRET = process.env.PROXY_SECRET;
const SSM_PARAM = process.env.SSM_PARAM_MONGODB_URI;

// Cached across warm invocations - never connect per request.
let clientPromise;

async function resolveUri() {
  const ssm = new SSMClient({});
  const res = await ssm.send(
    new GetParameterCommand({ Name: SSM_PARAM, WithDecryption: true })
  );
  return res.Parameter.Value;
}

async function getClient() {
  if (!clientPromise) {
    clientPromise = (async () => {
      const uri = await resolveUri();
      const client = new MongoClient(uri, {
        maxPoolSize: 5,
        serverSelectionTimeoutMS: 8000,
      });
      await client.connect();
      return client;
    })();
  }
  return clientPromise;
}

function json(statusCode, body) {
  return {
    statusCode,
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  };
}

export const handler = async (event) => {
  const method = event?.requestContext?.http?.method ?? "GET";
  const path = event?.rawPath ?? "/";
  const headers = event?.headers ?? {};

  // Only the Cloudflare proxy knows the shared secret.
  if (PROXY_SECRET && headers["x-proxy-secret"] !== PROXY_SECRET) {
    return json(403, { error: "forbidden" });
  }

  try {
    if (method === "GET" && (path === "/api/health" || path === "/health")) {
      const client = await getClient();
      await client.db().command({ ping: 1 });
      return json(200, { status: "ok", db: "connected" });
    }

    return json(404, { error: "not_found", path });
  } catch (err) {
    console.error("request_error", err);
    return json(500, { error: "internal_error", message: err.message });
  }
};
