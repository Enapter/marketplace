# Ubiquiti UniFi Dream Machine

This [Enapter Blueprint](https://go.enapter.com/marketplace-readme) monitors
Ubiquiti UniFi Dream Machine (UDM, UDM-Pro, UDM-SE) via the UniFi Integration
API using API Key authentication.

## Overview

The blueprint connects to your UDM's Integration API and reports real-time
network health, client counts, throughput, and system resource utilization.

## Telemetry

- **Throughput**: WAN download and upload (Mbps) derived from uplink rates
- **Clients**: total, wired (LAN), and wireless (WLAN) client counts
- **Devices**: number of adopted UniFi devices
- **System**: CPU and memory utilization, uptime

## Alerts

- No data from UDM (unreachable or bad API key)
- High CPU usage (>90%)
- High memory usage (>90%)

## Requirements

- UniFi Dream Machine running UniFi OS with Integration API support
- An API Key generated from the UniFi application
- Network connectivity between the Enapter Virtual UCM and the UDM

## Creating an API Key

1. Open the UniFi application on your UDM (e.g. `https://192.168.1.1`)
2. Go to **Settings** (gear icon)
3. Navigate to **Integrations** (under System or Advanced, depending on version)
4. Click **Create New API Key**
5. Give the key a descriptive name (e.g. "Enapter Monitoring")
6. Copy the generated key immediately — it is shown only once

> **Note**: API Keys are read-only. The blueprint does not modify any settings
> on your UDM.

## Configuration

- **IP Address** (`ip_address`): UDM IP address (e.g. `192.168.1.1`)
- **API Key** (`api_key`): The API key generated above
- **Site** (`site`): UniFi site name (default: `default`). Only needed if you
  have multiple sites configured.

## How It Works

The blueprint authenticates using the `Authorization: Bearer <API_KEY>` header
and polls the following Integration API endpoints every 15 seconds:

| Endpoint                                                        | Data                                        |
| --------------------------------------------------------------- | ------------------------------------------- |
| `GET /integration/v1/sites`                                     | Resolve site name to UUID                   |
| `GET /integration/v1/sites/{id}/devices`                        | Adopted device list, gateway identification |
| `GET /integration/v1/sites/{id}/devices/{id}/statistics/latest` | CPU, memory, uptime, uplink throughput      |
| `GET /integration/v1/sites/{id}/clients`                        | Total, wired, and wireless client counts    |

## References

- [UniFi Developer Portal](https://developer.ui.com/)
- [Enapter Blueprint SDK](https://developers.enapter.com)
