# SMA Sunny Tripower Blueprint Development

## Working With Modbus

### Download All Modbus Documents

SMA provides HTML files with Modbus registers specifications. Files can be manually downloaded from [SMA website](https://www.sma.de/en/products/product-features-interfaces/modbus-protocol-interface) or using the automated script: `scripts/download_modbus.sh`.

### Easy Way to Extract Enum Values

The following script will collect enum values from all downloaded Modbus HTML documents.

Note: [ripgrep](https://github.com/BurntSushi/ripgrep) must be installed.

```bash
rg --no-ignore -g '*_en.html' 40009 | grep -o '[0-9]*: [^<]*' | sort -u
```

## Working With Alerts

Run `scripts/generate_alerts.rb`, it will generate YAML declaration for all known alerts in an appropriate format.

## List of All SMA Sunny Boy Models

### Active Models

How to build this list:

1. Download all .zip files from [SMA documentation](https://www.sma.de/en/products/product-features-interfaces/modbus-protocol-interface)
2. Run: `for f in modbus/*/*_en.html; do grep 30053 "$f" | grep -o '[0-9]*:[^<]*'; done`
3. Copy here, sort, remove duplicates (vim: `sort u`)
4. Leave only names in brakets, remove marketing names. E.g. "Sunny Island 6.0H (SI 6.0H-12)" -> "SI 6.0H-12". vim: `s/\v: .*\((.*)\)/: \1`
5. Leave only Sunny Boy models (starts with `SB`).

```txt
19048: STP5.0-3SE-40
19049: STP6.0-3SE-40
19050: STP8.0-3SE-40
19051: STP10.0-3SE-40
9284: STP 20000TL-30
9285: STP 25000TL-30
9336: STP 15000TL-30
9337: STP 17000TL-30
9338: STP50-40
9339: STP50-US-40
9340: STP50-JP-40
9344: STP4.0-3AV-40
9345: STP5.0-3AV-40
9346: STP6.0-3AV-40
9347: STP8.0-3AV-40
9348: STP10.0-3AV-40
9366: STP3.0-3AV-40
9428: STP62-US-41
9429: STP50-US-41
9430: STP33-US-41
9431: STP50-41
9432: STP50-JP-41
```

### Archive Models

These models are no longer available in Modbus documentation and left here for backward compatibility.

```txt
9067: STP 10000TL-10
9068: STP 12000TL-10
9069: STP 15000TL-10
9070: STP 17000TL-10
9098: STP 5000TL-20
9099: STP 6000TL-20
9100: STP 7000TL-20
9101: STP 8000TL-10
9102: STP 9000TL-20
9103: STP 8000TL-20
9131: STP 20000TL-10
9139: STP 20000TLHE-10
9140: STP 15000TLHE-10
9181: STP 20000TLEE-10
9182: STP 15000TLEE-10
9281: STP 10000TL-20
9282: STP 11000TL-20
9283: STP 12000TL-20
```
