# Migrator

## Build It
`docker compose build`

## Usage
`docker compose run migrator --help`

## Export

Writes cloudtruth data to `export.json`:

`docker compose run migrator export --api-key old_api_key`

## Import

Reads cloudtruth data from `export.json`:

`docker compose run migrator import --api-key new_api_key`
