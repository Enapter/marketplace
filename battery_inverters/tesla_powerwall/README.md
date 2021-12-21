# Tesla Powerwall 2

This [Enapter Device Blueprint](https://github.com/Enapter/wip-marketplace#blue_book-enapter-device-blueprints) integrates **Tesla Powerwall 2** - a rechargeable home battery system - via [HTTP API](https://developers.enapter.com/docs/reference/vucm/http) implemented on [Enapter Virtual UCM](https://handbook.enapter.com/software/software.html#%F0%9F%92%8E-virtual-ucm).

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use [Enapter Gateway](https://handbook.enapter.com/software/gateway/2.0.0/setup/) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://handbook.enapter.com/software/software.html#%F0%9F%92%8E-virtual-ucm).
- [Upload](https://developers.enapter.com/docs/tutorial/uploading-blueprint/) this blueprint to ENP-VIRTUAL.
- Use `Configure` command in Enapter mobile app or Web to set up Tesla Powerwall 2 communication parameters:
  - IP address (use either static IP or DHCP reservation),
  - [Your Tesla account](https://www.tesla.com/teslaaccount) e-mail,
  - [Your Tesla account](https://www.tesla.com/teslaaccount) password.

## References

- [Tesla Powerwall 2 Owner's Manual](https://tesla-cdn.thron.com/delivery/public/document/tesla/94bd53b8-9297-40ad-b190-b97d0abcb520/bvlatuR/WEB/powerwall-2-ac-owners-manual-en-na)
- [Tesla Powerwall 2 API](https://github.com/vloschiavo/powerwall2)
