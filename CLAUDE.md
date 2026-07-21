# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Ruby gem providing a Rails ActiveRecord adapter for TiDB. It extends the standard `Mysql2Adapter` to support TiDB-specific DDL features in migrations. Requires Ruby 3.2+, Rails/ActiveRecord 7.2+, TiDB 5.0+.

## Details

Supported TiDB-specific DDL: clustered/non-clustered primary keys (`clustered: true/false`), `auto_id_cache`, `shard_row_id_bits`, and `pre_split_regions` table options, and the column-level `auto_random` option. TiDB-specific keywords are emitted inside TiDB version comments (`/*T![feature_id] ... */`) so the generated DDL also parses on plain MySQL; `auto_random` additionally falls back to `AUTO_INCREMENT` when the connected server is not TiDB (see `TidbAdapter#tidb?`).

## Commands

```bash
bin/setup                # bundle install
rake test                # run all tests (default rake task)
rake test TEST=test/activerecord/tidb/adapter_test.rb                          # single file
rake test TEST=test/activerecord/tidb/adapter_test.rb TESTOPTS="-n test_single_key_clustered"  # single test
bin/console              # IRB with the gem loaded
```

**Tests require a running TiDB instance** at `127.0.0.1:4000` with user `root` (no password) and a database named `tidb_test` (see `test/test_helper.rb`). Tests are integration-style: they run real migrations, then assert against the exact output of `SHOW CREATE TABLE`. Note TiDB renders its extensions as version comments, e.g. `PRIMARY KEY (`id`) /*T![clustered_index] CLUSTERED */` — expected SQL in tests must match this form. Each test creates/drops the `users` table.

## Architecture

Entry point `lib/activerecord-tidb-adapter.rb` registers the `"tidb"` adapter with ActiveRecord via a Railtie (test_helper registers it manually since Rails isn't loaded), and likewise registers `lib/activerecord/tasks/tidb_database_tasks.rb` (`ActiveRecord::Tasks::TiDBDatabaseTasks < MySQLDatabaseTasks`) with `ActiveRecord::Tasks::DatabaseTasks.register_task(/tidb/, ...)` — without this, `db:create`/`db:drop`/`db:purge`/`db:structure:dump`/`db:structure:load` raise `DatabaseNotSupported` because the adapter name `"tidb"` doesn't match Rails' built-in `/mysql/` pattern. The adapter layers TiDB behavior on top of the MySQL2 adapter classes:

- `lib/activerecord/connection_adapters/tidb_adapter.rb` — `TidbAdapter < Mysql2Adapter`. Connection setup, capability flags (`supports_clustered_index?` gates on TiDB >= 5.0).
- `lib/activerecord/connection_adapters/tidb/schema_statements.rb` — `TiDB::SchemaStatements`, included into the adapter. Wires in the TiDB `SchemaCreation`/`TableDefinition` and whitelists the TiDB options via `valid_table_definition_options`.
- `lib/activerecord/connection_adapters/tidb/schema_definitions.rb` — `TiDB::TableDefinition < MySQL::TableDefinition`. Captures the TiDB options from `create_table`, propagates `clustered` onto the primary key (including composite PKs via `TiDB::PrimaryKeyDefinition`) and the table options onto column definitions.
- `lib/activerecord/connection_adapters/tidb/schema_creation.rb` — `TiDB::SchemaCreation < MySQL::SchemaCreation`. Renders the actual SQL: `CLUSTERED`/`NONCLUSTERED` after `PRIMARY KEY`, and `AUTO_ID_CACHE` / `SHARD_ROW_ID_BITS` / `PRE_SPLIT_REGIONS` as table options.

The `clustered` option flows through two paths: table-level (`create_table :users, clustered: true`) via `TableDefinition#set_primary_key`, and column-level (`t.bigint :id, primary_key: true, clustered: false`) via `SchemaCreation#add_column_options!`. Adding a new TiDB option requires touching all three tidb/ files: whitelist it, capture it in `TableDefinition`, and render it in `SchemaCreation`.

Note the two namespaces: `ActiveRecord::ConnectionAdapters::TiDB::*` for adapter code, and `Activerecord::Tidb::Adapter` (in `lib/activerecord/tidb/`) for the gem version/module boilerplate.
