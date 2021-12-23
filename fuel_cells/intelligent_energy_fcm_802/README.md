# Intelligent Energy FCM 802

This [Enapter Device Blueprint](https://github.com/Enapter/marketplace#blue_book-enapter-device-blueprints) integrates **Intelligent Energy FCM 802** - fuel cell module products for stationary and portable applications with [CAN bus](https://developers.enapter.com/docs/reference/ucm/can).

This blueprint collects the fuel cell telemetry, while [`intelligent_energy_fcm_802_rl6`](../intelligent_energy_fcm_802_rl6) blueprint controls the fuel cell.

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use [Enapter ENP-CAN](https://handbook.enapter.com/modules/ENP-CAN/ENP-CAN.html) module for physical connection. See [connection instructions](https://handbook.enapter.com/modules/ENP-CAN/ENP-CAN.html#connection-examples) in the module manual.
- [Add ENP-CAN to your site](https://handbook.enapter.com/software/mobile/android_mobile_app.html#adding-sites-and-devices) using the mobile app.
- [Upload](https://developers.enapter.com/docs/tutorial/uploading-blueprint/) this blueprint to ENP-CAN.

## ENP-CAN Connection Diagram

<p align="left"><img height="auto" width="800" src=".assets/IE_FC_connection.png"></p>

## Troubleshooting

If the module is not receiving telemetry:

- Check the wiring and the resistor location according to [the diagram above](#enp-can-connection-diagram).
- Check the jumpers inside the ENP-CAN module (install if needed):
  - Dismount the antenna from the ENP-CAN module.
  - Remove the front cover.
  - Remove the back side of the module.
  - Carefully push the module control board down.
  - Install jumper `J5`, jumper `J3` H.speed or both according to the photo below:
    <details><summary>Jumper locations photo</summary>
    <p align="left"><img height="auto" width="800" src=".assets/enp_can-troubleshooting.png"></p>
    </details>

## References

- [Intelligent Energy FCM 802 technical specification](https://www.intelligent-energy.com/uploads/product_docs/IE-Lift_802.pdf)
- [Intelligent Energy FCM 802/804 User Manual](https://www.intelligent-energy.com/uploads/product_guides/FCM_802__804_User_Manual_WEB.pdf)
