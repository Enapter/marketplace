#!/usr/bin/env bash

cd "$(dirname "$(dirname "$0")")" || exit 1

url="https://www.sma.de$(curl -s 'https://www.sma.de/en/products/product-features-interfaces/modbus-protocol-interface' | grep -o '[^"]*documentsAjax[^"]*' | sed 's/\&amp;/\&/g')"
zips="$(curl -s "$url" | grep -o 'http[^"]*\.zip' | grep 'MODBUS-HTML_SB' | grep -v 'MODBUS-HTML_SBS' | sed 's/ /%20/g' | sort -u)"

mkdir modbus

for z in $zips; do echo "$z"; curl "$z" > "modbus/$(basename "$z")"; done
for z in modbus/*; do unzip "$z" -d modbus; done
