# Migrator

## Build It
`docker build -t migrator .`

## Export

Writes cloudtruth data to `/data/export.json`:

`docker run -it -v $(pwd):. migrator -o old_api_key -n new_api_key export`

## Import

Reads cloudtruth data from `/data/export.json`:

`docker run -it -v $(pwd):. migrator -o old_api_key -n new_api_key import`


