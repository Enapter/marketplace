# Intelligent Energy FCM 802

This _Enapter Device Blueprint_ integrates **Intelligent Energy FCM 802** - fuel cell module products for stationary and portable applications with [CAN bus](https://developers.enapter.com/docs/reference/ucm/can).

This blueprint collects the fuel cell telemetry, while [`intelligent_energy_fcm_802_rl6`](../intelligent_energy_fcm_802_rl6) blueprint controls the fuel cell.

Use [Enapter ENP-CAN](https://handbook.enapter.com/modules/ENP-CAN/ENP-CAN.html) module for physical connection. See [connection instructions](https://handbook.enapter.com/modules/ENP-CAN/ENP-CAN.html#connection-examples) in the module manual.

## CAN bus Communication Interface Parameters

- Baud rate: `500` kbps.

## ENP-CAN Connection Diagram

<p align="left"><img height="auto" width="800" src=".assets/IE_FC_connection.png"></p>

## Troubleshooting

If the blueprint doesn't collect telemetry, you can install additional jumpers inside the ENP-CAN module.

- Dismount the antenna from the ENP-CAN module
- Remove the front cover
- Remove the back side of the module
- Carefully push module control board down
- Install jumper J5, jumper J3 H.speed or both (see the picture below)

<p align="left"><img height="auto" width="800" src=".assets/enp_can-troubleshooting.png"></p>

## References

- [Intelligent Energy FCM 802 technical specification](https://www.intelligent-energy.com/uploads/product_docs/IE-Lift_802.pdf)
- [Intelligent Energy FCM 802/804 User Manual](https://www.intelligent-energy.com/uploads/product_guides/FCM_802__804_User_Manual_WEB.pdf)
