# Sfere µCv 4001

This [Enapter Device Blueprint](https://github.com/Enapter/wip-marketplace#blue_book-enapter-device-blueprints) integrates **Sfere µCv 4001** - programmable signal conditioner with [Modbus RTU](https://developers.enapter.com/docs/reference/ucm/modbus) over [RS-485 communication interface](https://developers.enapter.com/docs/reference/ucm/rs485).

Sfere µCv 4001 is used here as a gas acceptability controller that:

- gathers analog signal from gas concentration sensor (O2 in H2 in our case),
- manages solenoid valve through internal relay to close a pipe if the gas is not acceptable (concentration is higher than a configured threshold),
- exposes digital sensor value and relay state over Modbus RTU for ENP-RS485.

ENP-RS485 transmits the gas sensor value, µCv relay state, and gas acceptability status to Enapter Cloud for monitoring purposes.

## Connect to Enapter

- Sign up to using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use [Enapter ENP-RS485](https://handbook.enapter.com/modules/ENP-RS485/ENP-RS485.html) module for physical connection. See [connection instructions](https://handbook.enapter.com/modules/ENP-RS485/ENP-RS485.html#connection-examples) in the module manual.
- [Add ENP-RS485 to your site](https://handbook.enapter.com/software/mobile/android_mobile_app.html#adding-sites-and-devices) using the mobile app.
- [Upload](https://developers.enapter.com/docs/tutorial/uploading-blueprint/) this blueprint to ENP-RS485.

## References

- [Sfere µCv 4001 datasheet](https://ardetem-sfere.com/download/5424/TPIv4001-%C2%B5Cv4001-com-EN.pdf).
- Sfere µCv 4001 manual is [accessible for registered users](https://ardetem-sfere.com/en/tpiv-4001-%c2%b5cv-4001/).
- See [Enapter Blueprints Tutorial](https://developers.enapter.com/docs/) to get familiar with the blueprint concept and its development workflow.
