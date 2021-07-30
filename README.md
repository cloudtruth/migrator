# Migrator

## Build It

`docker compose build`

## Usage

`docker compose run --rm migrator --help`

## Export

Writes cloudtruth data to `export.json`:

`docker compose run --rm migrator --api-key old_api_key export`

## Import

Reads cloudtruth data from `export.json`:

`docker compose run --rm migrator --api-key new_api_key import`
