# Sonoff MINI R2

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates **Sonoff MINI R2** - a Wi-Fi DIY smart switch - via [HTTP API](https://go.enapter.com/developers-enapter-http) implemented on [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to Enapter Virtual UCM.
- Use the `Set Up Connection` command in the Enapter mobile or Web app to set up the Sonoff MINI R2 communication parameters:
  - Device IP address;
  - Port.

## How to find device IP Address and port information

### via mDNS tools

  There are a great many mDNS tools to choose from, so use whichever works best for you. For example purposes, we will cover [Discovery App for macOS](https://apps.apple.com/us/app/discovery-dns-sd-browser/id1381004916?mt=12) and [Avahi](https://avahi.org/).

- Get your device into [DYI Mode](https://sonoff.tech/diy-developer/).
- After your device was connected to your Wi-Fi, you can start scanning local network with [Discovery](https://apps.apple.com/us/app/discovery-dns-sd-browser/id1381004916?mt=12) or [Avahi](https://avahi.org/).
- In local networks Sonoff MINI R2 can usually be detected as _ewelink._tcp using [Ahavi](https://avahi.org/) and _ewelink._tcp (eWeLink devices supporting LAN control) using [Discovery](https://apps.apple.com/us/app/discovery-dns-sd-browser/id1381004916?mt=12).
- In [Discovery app](https://apps.apple.com/us/app/discovery-dns-sd-browser/id1381004916?mt=12) click on the drop-down list next to _ewelink._tcp and look for IP address and port information (e.g. 192.168.42.100:8081, 192.168.42.100 being IP address and 8081 being port).
- In [Avahi](https://avahi.org/) the same information might look something like this:
  - hostname = [eWeLink_<>.local];
  - address = [192.168.42.100] - this is IP address;
  - port = [8081].
- Write down IP address and port of your device and use this information in the `Set Up Connection` command in the Enapter mobile or Web app to set up the Sonoff MINI R2 communication parameters.

## References

- [Sonoff MINI R2 product page](https://sonoff.tech/product/diy-smart-switch/minir2/).
