# Sonoff MINI R2

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates **Sonoff MINI R2** - a Wi-Fi DIY smart switch - via [HTTP API](https://go.enapter.com/developers-enapter-http) implemented on [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to Enapter Virtual UCM.
- Use the `Set Up Connection` command in the Enapter mobile or Web app to set up the Sonoff MINI R2 communication parameters:
  - Device IP Address; 
  - Port.

## How to find device IP Adress and port informatiom

### via mDNS tools

There are a great many mDNS tools to choose from, so use whichever works best for you. For example purposes, we will cover [Discovery App](https://apps.apple.com/us/app/discovery-dns-sd-browser/id1381004916?mt=12) and [Avahi](https://avahi.org/).

- Get your device into [DYI Mode](https://sonoff.tech/diy-developer/).
- After your device was connected to Wi-Fi, you can start scanning local network with [Discovery](https://apps.apple.com/us/app/discovery-dns-sd-browser/id1381004916?mt=12) or [Avahi](https://avahi.org/).
- Sonoff MINI R2 in local network can usually be detected as  _ewelink._tcp (for Ahavi) and  _ewelink._tcp (eWeLink devices supporting LAN control for Discovery).
- In [Discovery](https://apps.apple.com/us/app/discovery-dns-sd-browser/id1381004916?mt=12) click on the drop down list next to _ewelink._tcp and look for IP address and port informatiin (e.g. 192.168.42.100:8081, 192.168.42.100 being IP address and 8081 being port).
- In [Avahi](https://avahi.org/) IP address and. port might look something like this 
    - hostname = [eWeLink_<>.local]
    - address = [192.168.42.100]
    - port = [8081]
- Write down IP address and port information.

## References

- [Sonoff MINI R2 product page](https://sonoff.tech/product/diy-smart-switch/minir2/.
