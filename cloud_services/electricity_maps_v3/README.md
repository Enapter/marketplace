# Electricity Maps

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates **Electricity Maps** API — a platform that provides real-time and historical carbon intensity data for electricity grids around the world. The data helps assess the carbon emissions associated with electricity generation in different regions to understand your energy system's carbon footprint and optimize load usage.

This blueprint provides the following data for a selected location (latitude, longitude):

- Carbon intensity (gCO2eq/kWh)
- Total power production (MW)
- Total power consumption (MW)
- Fossil free energy percentage
- Renewable energy percentage

## Electricity Maps Cloud Service API Access

1. Navigate to [https://api-portal.electricitymaps.com/](https://api-portal.electricitymaps.com/)
2. Tick `API` and enter your e-mail address

<img src="./.assets/01_Electricty_Maps_API.png" alt="Connect to Shelly Plus 2PM" width="25%" />

3. Click `Submit` button.
4. Save your token

## Connect to Enapter EMS

### Prerequisites

- You should have an [access to Enapter EMS](https://go.enapter.com/how-to-use-enapter-ems).
- You should have a Lua Runtime:
  - On the Gateway, you already have a Virtual UCM. You can also use a [Hardware UCM](https://go.enapter.com/how-to-provision-ucm).
  - In the Cloud you need a [Hardware UCM](https://go.enapter.com/how-to-provision-ucm).
- Register for an API access token at [Electricity Maps API Portal](https://api-portal.electricitymaps.com/).

### Steps

- [Create Lua Device](https://go.enapter.com/how-to-create-lua-device).
- Check the new Lua Device, [configure](https://go.enapter.com/how-to-configure-devices) them if needed.

## References

- [Electricity Maps](https://www.electricitymaps.com/)
- [Electricity Maps API Documentation](https://docs.electricitymaps.com/)
