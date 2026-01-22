# Intelligent Energy FCM 804 (V3)

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates **Intelligent Energy FCM 804** fuel cell module products for stationary and portable applications.

## Connect to Enapter

You need the following hardware to connect the fuel cell to Enapter via this blueprint:

- [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup)
- [Enapter ENP-RL6](https://go.enapter.com/handbook-enp-rl6) module
- [Enapter ENP-CAN](https://go.enapter.com/handbook-enp-can) module

## Setup Instructions

### 1. Physical Connection

Connect the fuel cell to Enapter via ENP-RL6 and ENP-CAN modules. See the [connection diagram below](#connection-diagram-example) and connection instructions for [ENP-RL6](https://go.enapter.com/handbook-enp-rl6-conn) and [ENP-CAN](https://go.enapter.com/handbook-enp-can-conn) in the module manuals.

### 2. Add Modules to Your Site

1. Sign up to the Enapter Cloud using the [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en))
2. [Add ENP-RL6](https://go.enapter.com/handbook-mobile-app) using the mobile app
3. [Add ENP-CAN](https://go.enapter.com/handbook-mobile-app) using the mobile app

### 3. Upload Generic IO Blueprints

1. [Upload](https://go.enapter.com/developers-upload-blueprint) the [Generic RL6 V3 blueprint](../../generic_io/rl6_v3) to ENP-RL6
2. [Upload](https://go.enapter.com/developers-upload-blueprint) the [Generic CAN V3 blueprint](../../generic_io/can_v3) to ENP-CAN

### 4. Configure ENP-CAN

Configure ENP-CAN via Device Settings:

- Set "Baud Rate" to 500 (or as per your device requirements)
- Set "Cache bucket size" to 10
- Set "Cache TTL (seconds)" to 10

### 5. Create Virtual UCM

1. Use Enapter Gateway to run Virtual UCM
2. Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm)
3. [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to the Virtual UCM

### 6. Configure This Blueprint

Use Device Settings to configure the fuel cell connection parameters:

- **CAN Index**: Pre-configured at factory (usually 1), obtain from device vendor
- **Troubleshooting Mode**: Enable to save CAN messages for analysis by Intelligent Energy support
- **Generic CAN UCM ID**: Hardware ID of the ENP-CAN module (find in device details)
- **Power Relay UCM ID**: Hardware ID of the ENP-RL6 module
- **Power Relay Channel**: Relay channel number (1-6) connected to FC power contact
- **Start Relay UCM ID**: Hardware ID of the ENP-RL6 module (same as power)
- **Start Relay Channel**: Relay channel number (1-6) connected to FC start contact

## Connection Diagram Example

<p align="left"><img height="auto" width="800" src=".assets/IE_FC_connection.png" alt="IE FC connection diagram"></p>

## Troubleshooting

If the module is not receiving telemetry:

- Check the wiring and resistor location according to [the diagram above](#connection-diagram-example)
- Check the jumpers inside the ENP-CAN module (install if needed):
  - Dismount the antenna from the ENP-CAN module
  - Remove the front cover
  - Remove the back side of the module
  - Carefully push the module control board down
  - Install jumper `J5`, jumper `J3` H.speed or both according to the photo below:
    <details><summary>Jumper locations photo</summary>
    <p align="left"><img height="auto" width="800" src=".assets/enp_can-troubleshooting.png" alt="ENP-CAN jumpers placement"></p>
    </details>

## References

- [Intelligent Energy FCM 804 Product Page](https://www.intelligent-energy.com/our-products/stationary-power/fcm-804/)
