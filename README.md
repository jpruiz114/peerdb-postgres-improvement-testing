# PeerDB Postgres Schema Object Migration Testing

This repository contains testing documentation and demo databases for testing the Postgres-to-Postgres schema migration feature that automatically migrates indexes, triggers, and constraints.

## Contents

- **SETUP.md** - Instructions for setting up PeerDB and the testing environment
- **MANUAL_TESTING.md** - Step-by-step guide for manually testing the schema migration feature
- **demo-databases/** - Docker Compose setup and SQL scripts for demo databases with various schema objects

## Purpose

This repository was created to provide guidance on how to test the Postgres schema object migration improvements. The files here were extracted from the `feature/postgres-schema-object-migration-with-docs` branch to serve as standalone testing documentation.

## Quick Start

1. Follow the setup instructions in `SETUP.md`
2. Start the demo databases using `demo-databases/start-demo-dbs.sh`
3. Follow the testing guide in `MANUAL_TESTING.md`

## Demo Databases

The demo databases include:
- **ecommerce** - Contains tables with indexes, triggers, and constraints
- **analytics** - Additional test scenarios

See `demo-databases/README.md` for more details.

