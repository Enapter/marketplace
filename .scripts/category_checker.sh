#!/bin/bash

ROOT="./"

dirs=$(find ${ROOT} -type d -mindepth 1 -maxdepth 1 -not -name '.*' -exec basename {} \;)

for dir in $dirs; do
  printf "Checking %s..." "${dir}"
  code=$(curl -sI -o/dev/null -w'%{http_code}' https://static.enapter.com/marketplace-categories/"${dir}".svg)
  if [ "$code" != "200" ]; then
    echo "failed"
    echo "::error::icon for category ${dir} not found, please create issue about it https://github.com/Enapter/marketplace/issues/new"
    exit 1
  fi

  if [ ! -f "${ROOT}${dir}/README.md" ]; then
    echo "failed"
    echo "::error::README.md for category ${dir} is required, but not found"
    exit 1
  fi

  echo "ok"
done
