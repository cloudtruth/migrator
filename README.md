# Migrator

## Build It

`docker compose build`

## Usage

`docker compose run --rm migrator --help`

## Export

Writes cloudtruth data to `export.json`:

`docker compose run --rm migrator export --api-key old_api_key`

## Import

Reads cloudtruth data from `export.json`:

`docker compose run --rm migrator import --api-key new_api_key`
