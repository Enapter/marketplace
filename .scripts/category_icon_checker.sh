#!/bin/bash

dirs=$(find ./ -type d -mindepth 1 -maxdepth 1 -not -name '.*' -exec basename {} \;)

for dir in $dirs; do
  printf "Checking %s..." "${dir}"
  code=$(curl -sI -o/dev/null -w'%{http_code}' https://static.enapter.com/marketplace-categories/"${dir}".svg)
  if [ "$code" == "200" ]; then
    echo "ok"
  else
    echo "failed"
    echo "::error::icon for category ${dir} not found, please create issue about it https://github.com/Enapter/marketplace/issues/new"
    exit 1
  fi
done
