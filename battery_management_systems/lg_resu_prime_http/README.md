# LG RESU (10|16)h Prime (HTTP)

This [Enapter Device Blueprint](https://github.com/Enapter/marketplace#blue_book-enapter-device-blueprints) integrates **LG RESU 10h and LG RESU 16h Prime** lithium battery control and monitoring via an undocumented http interface on the battery. [Enapter HTTP API](https://developers.enapter.com/docs/reference/vucm/http) is implemented on [Enapter Virtual UCM](https://handbook.enapter.com/software/software.html#%F0%9F%92%8E-virtual-ucm).

## Connect to Enapter

- Sign up to the Enapter Cloud using the [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use the [Enapter Gateway](https://handbook.enapter.com/software/gateway/2.0.0/setup/) to run the Virtual UCM.
- Create the [Enapter Virtual UCM](https://handbook.enapter.com/software/software.html#%F0%9F%92%8E-virtual-ucm).
- [Upload](https://developers.enapter.com/docs/tutorial/uploading-blueprint/) this blueprint to ENP-VIRTUAL.
- Please ensure that your installer is connecting the LAN connection of the battery to your network.
- Use the `Configure` command in the Enapter mobile or Web app to set up the LG RESU 10h/16h Prime:
  - IP address (use either static IP or DHCP reservation);

## References

- [LG RESU Prime Battery product page](https://www.lgessbattery.com/us/home-battery/product-info.lg)
