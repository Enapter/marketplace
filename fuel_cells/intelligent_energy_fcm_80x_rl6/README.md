# Control Relay for Intelligent Energy FCM 800 series

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates **control relay for Intelligent Energy FCM 800 series** via the [Enapter rl6 library](https://go.enapter.com/developers-enapter-rl6).

This blueprint controls the fuel cell, while the [`intelligent_energy_fcm_801_can`](../intelligent_energy_fcm_801_can) or [`intelligent_energy_fcm_804_can`](../intelligent_energy_fcm_804_can) blueprint collects the fuel cell telemetry.

## Connect to Enapter

- Sign up to the Enapter Cloud using the [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use the [Enapter ENP-RL6](https://go.enapter.com/handbook-enp-rl6) module for physical connection. See [connection instructions](https://go.enapter.com/handbook-enp-rl6-conn) in the module manual.
- [Add ENP-RL6 to your site](https://go.enapter.com/handbook-mobile-app) using the mobile app.
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to ENP-RL6.

## Relay Channels Connection

ENP-RL6 is connected to the D-type connector of Intelligent Energy FCM 800 series. You can choose any other (1-6) relay channels.

- Relay `channel 1` - start/stop Intelligent Energy FCM 800 series;
- Relay `channel 4` - power on/off Intelligent Energy FCM 800 series.

## ENP-RL6 Connection Diagram

<p align="left"><img height="auto" width="800" src=".assets/IE_FC_connection.png"></p>

## References

- [Intelligent Energy FCM 802 technical specification](https://go.enapter.com/intelligent-energy-fcm802-spec)
- [Intelligent Energy FCM 802/804 User Manual](https://go.enapter.com/intelligent-energy-user-manual)
- [Intelligent Energy FCM 801 User Manual](https://go.enapter.com/intelligent-energy-fcm801-user-manual)
