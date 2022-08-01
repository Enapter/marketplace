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

There are two ways:

### via eWELink app

- Follow installation instructions given in the [manual](https://sonoff.tech/wp-content/uploads/2021/03/%E8%AF%B4%E6%98%8E%E4%B9%A6-MINIR2-V1.1-20210305.pdf).
- After the device was added, in the app go to device information and look for MAC address.
- Access your router's admin page and search for the device with the same MAC Address.
- Write down IP Address and port information.
- Factory settings reset the device in the app and get it into the [Pairing Mod](https://sonoff.tech/wp-content/uploads/2021/03/%E8%AF%B4%E6%98%8E%E4%B9%A6-MINIR2-V1.1-20210305.pdf))
- On your PC or phone access ITEAD-****** Wi-Fi SSID and enter the password 12345678.
- Visit this [website](http://10.10.7.1/) and fill in WiFI SSID and password to your network.
- Sonoff MINI R2 is connected to your Wi-Fi and ready to be used.

### via mDNS

## References

- [Sonoff MINI R2 product page](https://sonoff.tech/product/diy-smart-switch/minir2/.
