# Sfere µCv 4001

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates **Sfere µCv 4001** - programmable signal conditioner with [Modbus RTU](https://go.enapter.com/developers-enapter-modbus) over [RS-485 communication interface](https://go.enapter.com/developers-enapter-rs485).

Sfere µCv 4001 is used here as a gas acceptability controller that:

- gathers an analog signal from a gas concentration sensor (O2 in H2 in our case);
- manages the solenoid valve through internal relay to close a pipe if the O2 concentration is not acceptable (concentration is higher than a configured threshold);
- communicates the digital sensor value and relay state over Modbus RTU for ENP-RS485.

ENP-RS485 transmits the gas sensor value, µCv relay state, and gas acceptability status to the Enapter Cloud for monitoring purposes.

## Connect to Enapter

- Sign up to the Enapter Cloud using the [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use the [Enapter ENP-RS485](https://go.enapter.com/handbook-enp-rs485) module for physical connection. See [connection instructions](https://go.enapter.com/handbook-enp-rs485-conn) in the module manual.
- [Add ENP-RS485 to your site](https://go.enapter.com/handbook-mobile-app) using the mobile app.
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to ENP-RS485.

## References

- [Sfere µCv 4001 datasheet](https://go.enapter.com/sfere-ucv4001).
- See the [Enapter Blueprints Tutorial](https://go.enapter.com/developers-docs) to get familiar with the blueprint concept and its development workflow.
