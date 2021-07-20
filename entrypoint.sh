#!/usr/bin/env bash

# fail fast
set -e

function usage {
  echo "usage: migrator [options] export|import"
  echo
  echo "  Options:"
  echo
  echo "    -o apikey  The apikey for old platform"
  echo "    -n apikey  The apikey for new platform"
  echo
  exit 1
}

while getopts ":o:n:" opt; do
  case $opt in
    o)
      oldkey="$OPTARG"
      ;;
    n)
      newkey="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if (( $# != 1));
then
  usage
fi

if [[ ! -d /data ]]; then
  echo "Docker mount /data for sharing data between export and import (/data/export.json)"
  echo "e.g. docker run -it -v \$(pwd):/data) migrator"
  exit 1
fi

action=$1; shift

case $action in

  export)
    echo "Starting export"
    cd /data
    export CLOUDTRUTH_API_KEY="$oldkey"
    ln -sf /usr/local/bin/cloudtruth-${CT_CLI_OLD_VER} $APP_DIR/bin/cloudtruth
    exec $APP_DIR/bin/export.rb
  ;;

  import)
    echo "Starting import"
    cd /data
    export CLOUDTRUTH_API_KEY="$newkey"
    ln -sf /usr/local/bin/cloudtruth-${CT_CLI_NEW_VER} $APP_DIR/bin/cloudtruth
    exec $APP_DIR/bin/import.rb
  ;;

  bash)
    if [ "$#" -eq 0 ]; then
      bash_args=( -i )
    else
      bash_args=( "$@" )
    fi
    exec bash "${bash_args[@]}"
  ;;

  *)
    exec $action "$@"
  ;;

esac
