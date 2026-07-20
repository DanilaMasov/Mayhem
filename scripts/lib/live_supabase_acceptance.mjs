import { spawn } from "node:child_process";
import { readdir } from "node:fs/promises";
import path from "node:path";

export const disposableConfirmation = "I_UNDERSTAND_THIS_IS_DISPOSABLE";
export const disposableResetConfirmation =
  "I_UNDERSTAND_THIS_RESETS_THE_DISPOSABLE_DATABASE";
export const noDisposableReset = "DO_NOT_RESET";

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
  const resetValue = (environment.MAYHEM_R2_RESET_EXISTING ?? "").trim();
  if (
    resetValue &&
    resetValue !== noDisposableReset &&
    resetValue !== disposableResetConfirmation
  ) {
    throw new Error("R2 disposable reset confirmation is invalid");
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
  assertMatchingHostedProject(supabaseUrl, database, localHttp);

  return Object.freeze({
    environmentId,
    supabaseUrl: supabaseUrl.toString().replace(/\/$/, ""),
    anonKey: environment.SUPABASE_ANON_KEY.trim(),
    databaseUrl,
    resetExisting: resetValue === disposableResetConfirmation
  });
}

function assertMatchingHostedProject(supabaseUrl, databaseUrl, localHttp) {
  if (localHttp) return;
  const hostMatch = supabaseUrl.hostname.match(
    /^([a-z0-9]{20})\.supabase\.co$/i
  );
  if (!hostMatch) {
    throw new Error("R2 hosted Supabase URL does not expose a project ref");
  }
  const projectRef = hostMatch[1];
  const databaseUser = decodeURIComponent(databaseUrl.username);
  const directTarget =
    databaseUrl.hostname === `db.${projectRef}.supabase.co` &&
    databaseUser === "postgres";
  const poolerTarget =
    databaseUrl.hostname.endsWith(".pooler.supabase.com") &&
    databaseUser === `postgres.${projectRef}`;
  if (!directTarget && !poolerTarget) {
    throw new Error("R2 Supabase and database targets do not match");
  }
}

export function safeEnvironmentSummary(config) {
  const url = new URL(config.supabaseUrl);
  return Object.freeze({
    environmentId: config.environmentId,
    supabaseHost: url.hostname,
    transport: url.protocol.replace(":", ""),
    databaseConfigured: true,
    anonKeyConfigured: true,
    resetExisting: config.resetExisting
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
    this.connectionEnvironment = postgresConnectionEnvironment(databaseUrl);
    this.executable = executable;
    this.spawnProcess = spawnProcess;
  }

  async verifyAvailable() {
    await this.#run(["--version"], { connect: false });
  }

  async resetDisposableTarget(confirmation) {
    if (confirmation !== disposableResetConfirmation) {
      throw new Error("R2 disposable reset confirmation is missing");
    }
    await this.query(`
begin;
drop schema if exists public cascade;
create schema public;
grant all on schema public to postgres, service_role;
grant usage on schema public to anon, authenticated;
delete from auth.users;
commit;
notify pgrst, 'reload schema';
`);
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
      "--file=-"
    ], { input: `${sql}\n` });
  }

  #run(argumentsList, { connect = true, input } = {}) {
    return new Promise((resolve, reject) => {
      const child = this.spawnProcess(this.executable, argumentsList, {
        env: {
          ...psqlProcessEnvironment(process.env),
          PGCONNECT_TIMEOUT: "10",
          ...(connect ? this.connectionEnvironment : {})
        },
        stdio: [input === undefined ? "ignore" : "pipe", "pipe", "pipe"]
      });
      let stdout = "";
      let stderr = "";
      child.stdout.on("data", (chunk) => {
        stdout += chunk;
      });
      child.stderr.on("data", (chunk) => {
        stderr += chunk;
      });
      if (input !== undefined) child.stdin.end(input);
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

export class FlutterLiveClientRunner {
  constructor({
    config,
    executable = "flutter",
    spawnProcess = spawn,
    baseEnvironment = process.env
  }) {
    this.config = config;
    this.executable = executable;
    this.spawnProcess = spawnProcess;
    this.baseEnvironment = baseEnvironment;
  }

  run(mobileRoot) {
    return new Promise((resolve, reject) => {
      const child = this.spawnProcess(
        this.executable,
        [
          "test",
          "--no-pub",
          "--no-test-assets",
          "-j",
          "1",
          "test/live/r2_live_supabase_test.dart"
        ],
        {
          cwd: mobileRoot,
          env: {
            ...flutterProcessEnvironment(this.baseEnvironment),
            MAYHEM_R2_ENVIRONMENT_ID: this.config.environmentId,
            MAYHEM_R2_CONFIRM_DISPOSABLE: disposableConfirmation,
            MAYHEM_R2_RUN_LIVE: "true",
            SUPABASE_URL: this.config.supabaseUrl,
            SUPABASE_ANON_KEY: this.config.anonKey
          },
          stdio: ["ignore", "pipe", "pipe"]
        }
      );
      let stdout = "";
      child.stdout.on("data", (chunk) => {
        stdout += chunk;
      });
      child.stderr.on("data", () => {});
      child.on("error", () => {
        reject(new Error("R2 requires an available flutter executable"));
      });
      child.on("close", (code) => {
        if (code !== 0) {
          reject(new Error(`R2 Flutter client probe failed (${code})`));
          return;
        }
        try {
          const marker = stdout.match(
            /MAYHEM_R2_CLIENT_REPORT:([A-Za-z0-9_-]+=*)/
          );
          if (!marker) throw new Error("missing report marker");
          const report = JSON.parse(
            Buffer.from(marker[1], "base64url").toString("utf8")
          );
          if (
            report?.result !== "passed" ||
            report.environmentId !== this.config.environmentId ||
            !Array.isArray(report.checks)
          ) {
            throw new Error("invalid report");
          }
          resolve(report);
        } catch {
          reject(new Error("R2 Flutter client probe returned an invalid report"));
        }
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

function postgresConnectionEnvironment(databaseUrl) {
  let database;
  try {
    database = new URL(databaseUrl);
  } catch {
    throw new Error("R2 database URL must be a valid PostgreSQL URI");
  }
  if (!["postgres:", "postgresql:"].includes(database.protocol)) {
    throw new Error("R2 database URL must use postgresql://");
  }

  const databaseName = decodeURIComponent(database.pathname.replace(/^\//, ""));
  if (!database.hostname || !database.username || !databaseName) {
    throw new Error("R2 database URL is missing required connection fields");
  }

  return {
    PGHOST: database.hostname,
    PGPORT: database.port || "5432",
    PGDATABASE: databaseName,
    PGUSER: decodeURIComponent(database.username),
    PGPASSWORD: decodeURIComponent(database.password),
    ...(database.searchParams.has("sslmode")
      ? { PGSSLMODE: database.searchParams.get("sslmode") }
      : {})
  };
}

function flutterProcessEnvironment(environment) {
  const allowed = ["PATH", "HOME", "LANG", "LC_ALL", "TMPDIR"];
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
  payload = {},
  occurredAtUtc = new Date().toISOString(),
  contentId = null,
  contentRevision = null
}) {
  return {
    eventId,
    installationId,
    clientSequence,
    schemaVersion: 2,
    eventType,
    assignmentId: null,
    attemptId: null,
    contentId,
    contentRevision,
    occurredAtUtc,
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
