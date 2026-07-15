import { spawn } from "node:child_process";
import { readdir } from "node:fs/promises";
import path from "node:path";

export const disposableConfirmation = "I_UNDERSTAND_THIS_IS_DISPOSABLE";

const requiredVariables = [
  "MAYHEM_R2_ENVIRONMENT_ID",
  "MAYHEM_R2_CONFIRM_DISPOSABLE",
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY"
];

export function loadLiveSupabaseConfig(environment = process.env) {
  const missing = requiredVariables.filter((name) => !environment[name]?.trim());
  const databaseUrl = (
    environment.SUPABASE_DB_URL ?? environment.DATABASE_URL ?? ""
  ).trim();
  if (!databaseUrl) missing.push("SUPABASE_DB_URL or DATABASE_URL");
  if (missing.length > 0) {
    throw new Error(`R2 preflight missing: ${missing.join(", ")}`);
  }

  const environmentId = environment.MAYHEM_R2_ENVIRONMENT_ID.trim();
  if (!/^[a-z0-9][a-z0-9._-]{2,63}$/i.test(environmentId)) {
    throw new Error("R2 environment identifier is invalid");
  }
  if (/prod(uction)?/i.test(environmentId)) {
    throw new Error("R2 refuses an environment identifier containing production");
  }
  if (environment.MAYHEM_R2_CONFIRM_DISPOSABLE !== disposableConfirmation) {
    throw new Error("R2 disposable-environment confirmation is missing");
  }

  const supabaseUrl = new URL(environment.SUPABASE_URL.trim());
  const localHttp =
    supabaseUrl.protocol === "http:" &&
    ["localhost", "127.0.0.1", "[::1]"].includes(supabaseUrl.hostname);
  if (supabaseUrl.protocol !== "https:" && !localHttp) {
    throw new Error("R2 Supabase URL must use HTTPS outside localhost");
  }
  const database = new URL(databaseUrl);
  if (!["postgres:", "postgresql:"].includes(database.protocol)) {
    throw new Error("R2 database URL must use PostgreSQL");
  }

  return Object.freeze({
    environmentId,
    supabaseUrl: supabaseUrl.toString().replace(/\/$/, ""),
    anonKey: environment.SUPABASE_ANON_KEY.trim(),
    databaseUrl
  });
}

export function safeEnvironmentSummary(config) {
  const url = new URL(config.supabaseUrl);
  return Object.freeze({
    environmentId: config.environmentId,
    supabaseHost: url.hostname,
    transport: url.protocol.replace(":", ""),
    databaseConfigured: true,
    anonKeyConfigured: true
  });
}

export async function migrationPlan(repositoryRoot) {
  const directory = path.join(repositoryRoot, "supabase", "migrations");
  const files = (await readdir(directory))
    .filter((name) => /^\d{12}_[a-z0-9_]+\.sql$/.test(name))
    .sort();
  if (files.length === 0 || new Set(files).size !== files.length) {
    throw new Error("R2 migration plan is empty or ambiguous");
  }
  return files.map((name) => ({
    version: name.slice(0, 12),
    name,
    path: path.join(directory, name)
  }));
}

export class PsqlRunner {
  constructor({ databaseUrl, executable = "psql", spawnProcess = spawn }) {
    this.databaseUrl = databaseUrl;
    this.executable = executable;
    this.spawnProcess = spawnProcess;
  }

  async verifyAvailable() {
    await this.#run(["--version"], { connect: false });
  }

  async assertMayhemSchemaIsEmpty() {
    const tables = [
      "quests_pool_cloud",
      "user_installations",
      "quest_events_cloud",
      "content_item_revisions",
      "user_events",
      "seasons",
      "data_deletion_receipts"
    ];
    const query = `select count(*) from information_schema.tables where table_schema = 'public' and table_name in (${tables
      .map((name) => `'${name}'`)
      .join(",")})`;
    const output = await this.query(query);
    if (Number.parseInt(output, 10) !== 0) {
      throw new Error("R2 target already contains Mayhem tables; refusing destructive reuse");
    }
  }

  async applyMigration(filePath) {
    await this.#run([
      "--no-psqlrc",
      "--set=ON_ERROR_STOP=1",
      "--single-transaction",
      `--file=${filePath}`
    ]);
  }

  query(sql, variables = {}) {
    const variableArguments = Object.entries(variables).map(
      ([name, value]) => `--set=${name}=${value}`
    );
    return this.#run([
      "--no-psqlrc",
      "--set=ON_ERROR_STOP=1",
      "--tuples-only",
      "--no-align",
      ...variableArguments,
      `--command=${sql}`
    ]);
  }

  #run(argumentsList, { connect = true } = {}) {
    return new Promise((resolve, reject) => {
      const child = this.spawnProcess(this.executable, argumentsList, {
        env: {
          ...psqlProcessEnvironment(process.env),
          PGCONNECT_TIMEOUT: "10",
          ...(connect ? { PGDATABASE: this.databaseUrl } : {})
        },
        stdio: ["ignore", "pipe", "pipe"]
      });
      let stdout = "";
      let stderr = "";
      child.stdout.on("data", (chunk) => {
        stdout += chunk;
      });
      child.stderr.on("data", (chunk) => {
        stderr += chunk;
      });
      child.on("error", () => {
        reject(new Error("R2 requires an available psql executable"));
      });
      child.on("close", (code) => {
        if (code === 0) {
          resolve(stdout.trim());
          return;
        }
        reject(
          new Error(
            `R2 PostgreSQL command failed (${code}): ${sanitizeDiagnostic(stderr).replaceAll(this.databaseUrl, "<redacted>")}`
          )
        );
      });
    });
  }
}

function psqlProcessEnvironment(environment) {
  const allowed = [
    "PATH",
    "HOME",
    "LANG",
    "LC_ALL",
    "TMPDIR",
    "SSL_CERT_FILE",
    "SSL_CERT_DIR",
    "PGSSLMODE",
    "PGSSLROOTCERT",
    "PGSSLCRL"
  ];
  return Object.fromEntries(
    allowed
      .filter((name) => environment[name] !== undefined)
      .map((name) => [name, environment[name]])
  );
}

export class SupabaseAcceptanceClient {
  constructor({ supabaseUrl, anonKey, fetchRequest = fetch }) {
    this.supabaseUrl = supabaseUrl;
    this.anonKey = anonKey;
    this.fetchRequest = fetchRequest;
  }

  async signUpAnonymous() {
    const response = await this.request("/auth/v1/signup", { body: {} });
    return parseSession(response);
  }

  async refresh(session) {
    const response = await this.request(
      "/auth/v1/token?grant_type=refresh_token",
      { body: { refresh_token: session.refreshToken } }
    );
    return parseSession(response);
  }

  rpc(functionName, body, accessToken) {
    return this.request(`/rest/v1/rpc/${functionName}`, {
      body,
      accessToken
    });
  }

  rest(pathname, { method = "GET", body, accessToken } = {}) {
    return this.request(`/rest/v1/${pathname}`, {
      method,
      body,
      accessToken
    });
  }

  async request(
    pathname,
    { method = "POST", body, accessToken, allowFailure = false } = {}
  ) {
    const response = await this.fetchRequest(`${this.supabaseUrl}${pathname}`, {
      method,
      headers: {
        apikey: this.anonKey,
        authorization: `Bearer ${accessToken ?? this.anonKey}`,
        ...(body === undefined ? {} : { "content-type": "application/json" })
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) })
    });
    const text = await response.text();
    let value = null;
    if (text.trim()) {
      try {
        value = JSON.parse(text);
      } catch {
        if (!allowFailure) throw new Error(`R2 ${pathname} returned non-JSON`);
      }
    }
    if (!response.ok && !allowFailure) {
      throw new Error(`R2 ${pathname} failed with HTTP ${response.status}`);
    }
    return { ok: response.ok, status: response.status, value };
  }
}

export function canonicalEvent({
  eventId,
  installationId,
  clientSequence,
  eventType,
  payload = {}
}) {
  return {
    eventId,
    installationId,
    clientSequence,
    schemaVersion: 2,
    eventType,
    assignmentId: null,
    attemptId: null,
    contentId: null,
    contentRevision: null,
    occurredAtUtc: new Date().toISOString(),
    timezoneId: "Etc/UTC",
    timezoneOffsetMinutes: 0,
    payload
  };
}

function parseSession(response) {
  const value = response.value;
  if (
    !value?.user?.id ||
    !value.access_token ||
    !value.refresh_token ||
    !Number.isFinite(value.expires_in)
  ) {
    throw new Error("R2 auth response did not contain a complete session");
  }
  return Object.freeze({
    userId: value.user.id,
    accessToken: value.access_token,
    refreshToken: value.refresh_token,
    expiresIn: value.expires_in
  });
}

function sanitizeDiagnostic(value) {
  return value.replace(/[\r\n]+/g, " ").trim().slice(0, 240) || "no diagnostic";
}
