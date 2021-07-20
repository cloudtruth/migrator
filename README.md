# Migrator

docker build -t migrator .
docker run -it -v $(pwd):. migrator -o old_api_key -n new_api_key export
docker run -it -v $(pwd):. migrator -o old_api_key -n new_api_key import


