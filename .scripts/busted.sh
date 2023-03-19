#!/bin/bash
set -e

luarocks install busted
tests_failed="no"
echo "============= RUN TESTS ============="
while IFS= read -r -d '' file
do
  d=$(dirname "$file")
  echo "== TEST $d"
  has_tests=$(cat "$file" <(echo "if test ~=nil then print('yes') end") | lua)
  if [ "$has_tests" = "yes" ]; then
    pushd "$d" > /dev/null
    if ! luarocks test; then
      echo -e "\033[0;31mFAILED\033[0m"
      tests_failed="yes"
    fi
    popd > /dev/null
  else
    echo -e "\033[0;33mSKIP\033[0m"
  fi
done < <(find . -type f -name "*.rockspec" -not -path './.git/*' -not -path './.luarocks/*' -print0)

if [ "$tests_failed" = "yes" ]; then
  exit 1
fi
