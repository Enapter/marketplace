# Control Relay for Intelligent Energy FCM 802

This _Enapter Device Blueprint_ integrates **control relay for Intelligent Energy FCM 802** via [Enapter rl6 library](https://developers.enapter.com/docs/reference/ucm/rl6).

This blueprint controls the fuel cell, while [`intelligent_energy_fcm_802`](../intelligent_energy_fcm_802) blueprint collects the fuel cell telemetry.

Use [Enapter ENP-RL6](https://handbook.enapter.com/modules/ENP-RL6/ENP-RL6.html) module for physical connection. See [connection instructions](https://handbook.enapter.com/modules/ENP-RL6/ENP-RL6.html#connection-example) in the module manual.

## Relay Channels Connection

ENP-RL6 connected to D-type connector of Intelligent Energy FCM 802. You can choose any other (1-6) relay channels.

- Relay `channel 1` - start/stop Intelligent Energy FCM 802;
- Relay `channel 4` - power on/off Intelligent Energy FCM 802.

## ENP-RL6 Connection Diagram

<p align="left"><img height="auto" width="800" src=".assets/IE_FC_connection.png"></p>

## References

- [Intelligent Energy FCM 802 technical specification](https://www.intelligent-energy.com/uploads/product_docs/IE-Lift_802.pdf)
- [Intelligent Energy FCM 802/804 User Manual](https://www.intelligent-energy.com/uploads/product_guides/FCM_802__804_User_Manual_WEB.pdf)
