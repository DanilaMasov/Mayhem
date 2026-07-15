import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const migrations = [
  {
    version: "v5",
    source: "mobile/database/migrations/005_feed_vnext.sql",
    output: "mobile/lib/core/database/migrations/v5_feed_vnext_sql.g.dart",
    constant: "v5FeedVNextStatements",
    minimumStatements: 10
  },
  {
    version: "v6",
    source: "mobile/database/migrations/006_feed_vertical_slice.sql",
    output: "mobile/lib/core/database/migrations/v6_feed_vertical_slice_sql.g.dart",
    constant: "v6FeedVerticalSliceStatements",
    minimumStatements: 1
  }
];

for (const migration of migrations) {
  const sourcePath = path.join(root, migration.source);
  const outputPath = path.join(root, migration.output);
  const source = await readFile(sourcePath, "utf8");
  const statements = source
    .split(/^-- statement\s*$/mu)
    .slice(1)
    .map((value) => value.trim())
    .filter(Boolean);

  if (statements.length < migration.minimumStatements) {
    throw new Error(
      `Expected a complete ${migration.version} migration, received ${statements.length} statements`
    );
  }
  for (const statement of statements) {
    if (statement.includes("'''")) {
      throw new Error("Migration statement cannot contain Dart raw-string delimiter");
    }
  }

  const generated = [
    "// GENERATED CODE - DO NOT MODIFY BY HAND.",
    `// Source: ${migration.source}`,
    "",
    `const ${migration.constant} = <String>[`,
    ...statements.map((statement) => `  r'''${statement}\n''',`),
    "];",
    ""
  ].join("\n");

  if (process.argv.includes("--check")) {
    const existing = await readFile(outputPath, "utf8").catch(() => "");
    if (existing !== generated) {
      throw new Error(`Generated ${migration.version} Dart migration is out of date`);
    }
    console.log(
      `Verified mobile ${migration.version} migration: ${statements.length} statements`
    );
  } else {
    await writeFile(outputPath, generated);
    console.log(
      `Generated mobile ${migration.version} migration: ${statements.length} statements`
    );
  }
}
