# SMA Sunny Boy Blueprint Development

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
9301: SB1.5-1VL-40
9302: SB2.5-1VL-40
9303: SB2.0-1VL-40
9304: SB5.0-1SP-US-40
9305: SB6.0-1SP-US-40
9306: SB7.7-1SP-US-40
9319: SB3.0-1AV-40
9320: SB3.6-1AV-40
9321: SB4.0-1AV-40
9322: SB5.0-1AV-40
9328: SB3.0-1SP-US-40
9329: SB3.8-1SP-US-40
9330: SB7.0-1SP-US-40
9401: SB3.0-1AV-41
9402: SB3.6-1AV-41
9403: SB4.0-1AV-41
9404: SB5.0-1AV-41
9405: SB6.0-1AV-41
9455: SB5.5-LV-JP-41
```

### Archive Models

These models are no longer available in Modbus documentation and left here for backward compatibility.

```txt
9015: SB 700
9016: SB 700U
9017: SB 1100
9018: SB 1100U
9019: SB 1100LV
9020: SB 1700
9021: SB 1900TLJ
9022: SB 2100TL
9023: SB 2500
9024: SB 2800
9025: SB 2800i
9026: SB 3000
9027: SB 3000US
9028: SB 3300
9029: SB 3300U
9030: SB 3300TL
9031: SB 3300TL HC
9032: SB 3800
9033: SB 3800U
9034: SB 4000US
9035: SB 4200TL
9036: SB 4200TL HC
9037: SB 5000TL
9038: SB 5000TLW
9039: SB 5000TL HC
9066: SB 1200
9074: SB 3000TL-21
9075: SB 4000TL-21
9076: SB 5000TL-21
9086: SB 3800US-10
9104: SB 3000TL-JP-21
9105: SB 3500TL-JP-21
9106: SB 4000TL-JP-21
9107: SB 4500TL-JP-21
9109: SB 1600TL-10
9160: SB 3600TL-20
9162: SB 3500TL-JP-22
9164: SB 4500TL-JP-22
9165: SB 3600TL-21
9177: SB 240-10
9183: SB 2000TLST-21
9184: SB 2500TLST-21
9185: SB 3000TLST-21
9198: SB 3000TL-US-22
9199: SB 3800TL-US-22
9200: SB 4000TL-US-22
9201: SB 5000TL-US-22
9225: SB 5000SE-10
9226: SB 3600SE-10
9274: SB 6000TL-US-22
9275: SB 7000TL-US-22
9293: SB 7700TL-US-22
```
