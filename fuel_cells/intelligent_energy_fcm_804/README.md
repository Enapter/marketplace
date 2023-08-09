# Intelligent Energy FCM 804

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates **Intelligent Energy FCM 804** fuel cell module products for stationary and portable applications.

This blueprint provides a full control and information about the fuel cell via single device. Another way is integrate it and use via two separate blueprints: the [`intelligent_energy_fcm_80x_rl6`](../intelligent_energy_fcm_80x_rl6) to control and [`intelligent_energy_fcm_804_can`](../intelligent_energy_fcm_804_can) to collects the telemetry.

## Connect to Enapter

You need the following hardware to connect the fuel cell to Enapter via this blueprint:

- [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup).
- [Enapter ENP-RL6](https://go.enapter.com/handbook-enp-rl6) module.
- [Enapter ENP-CAN](https://go.enapter.com/handbook-enp-can) module.

Step by step connection instructions:

- Sign up to the Enapter Cloud using the [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Physicaly Connect the fuel cell to Enapter via ENP-RL6 and ENP-CAN modules. See the connection diagram below and connection instructions for [ENP-RL6](https://go.enapter.com/handbook-enp-rl6-conn) and [ENP-CAN](https://go.enapter.com/handbook-enp-can-conn) in the module manual.
- [Add ENP-RL6 to your site](https://go.enapter.com/handbook-mobile-app) using the mobile app.
- [Add ENP-CAN to your site](https://go.enapter.com/handbook-mobile-app) using the mobile app.
- [Upload](https://go.enapter.com/developers-upload-blueprint) the [Generic IO blueprint](../../generic_io/rl6) to ENP-RL6.
- [Upload](https://go.enapter.com/developers-upload-blueprint) the [Generic IO blueprint](../../generic_io/can) to ENP-CAN.
- Configure ENP-CAN via `Configure` command in the Enapter mobile or Web app:
  - Set "Baud Rate" to desired value (500 we suppose).
  - Set "Cache bucket size" to 10.
  - Set "Cache TTL (seconds)" to 10.
- Use Enapter Gateway to run Virtual UCM.
- Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to Enapter Virtual UCM.
- Use the `Configure` command in the Enapter mobile or Web app to set up the fuel cell communication parameters.
  - UCM hardware IDs of the CAN and RL-6 generics IO.
  - Relay channels for power on/off and start/stop the fuel cell.

## Connection Diagram Example

<p align="left"><img height="auto" width="800" src=".assets/IE_FC_connection.png"></p>

## Troubleshooting

If the module is not receiving telemetry:

- Check the wiring and the resistor location according to [the diagram above](#connection-diagram-example).
- Check the jumpers inside the ENP-CAN module (install if needed):
  - Dismount the antenna from the ENP-CAN module.
  - Remove the front cover.
  - Remove the back side of the module.
  - Carefully push the module control board down.
  - Install jumper `J5`, jumper `J3` H.speed or both according to the photo below:
    <details><summary>Jumper locations photo</summary>
    <p align="left"><img height="auto" width="800" src=".assets/enp_can-troubleshooting.png"></p>
    </details>
