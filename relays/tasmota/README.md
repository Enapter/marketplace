# Generic Tasmota 

This [Enapter Device Blueprint](https://github.com/Enapter/marketplace#blue_book-enapter-device-blueprints) is meant to integrate with any [Tasmota](https://tasmota.github.io/docs/) device. **Tasmota** is opensource firmware, it runs on the ESP32 & ESP8266 chip. Tasmota firmware forms the basis for a lot of smart relays, smart sensors, smart sockets including loads of commercial vendors like [Nous](https://nous.technology/). But the ESP32 & ESP8266 essentially are very small webservers on a chip, and you can include them in any circuit board, so the combination of a chip, the tasmota firmware, and this blue print enables you to connect any device to the enapter cloud. 

The blueprint essentially is a wrapper around the Tasmota interface. It enables all commands which are supported by the tasmota device. This makes it a very powerful interface, but it also exposes a potential security thread. You should probably disable some commands on the tasmota firmware, or disable the generic command in this blueprint and only enable the once for your use case.   

## Setup

The Tasmota device and the gateway must be able to communicate with each other over a local IP, so make sure that they are linked to the same network.  

For any specific questions about Tasmota look at the [Tasmota docs](https://tasmota.github.io/docs/)

## Set up config

Make sure to configure the device before you start using it, using the configure command. The configuration has two parameters

1. The ADDRESS property should be filled with the local IP address for example 192.168.8.212 over which the gateway can connect to the device
2. The PASSWORD property is optional, it is only required if the Tasmota is set up in such a way that a password is required to connect to the api. Be aware that it is only a very thin layer of extra security and you should not depend purely on this feature for your security strategy

## Command

There are three commands to control the device

1. turn_on will turn on the device
2. turn_off will turn the device off
3. tasmota_command is a generic command. You can pass in any commands supported by your device, a full list of commands can be found here [Tasmota Commands](https://tasmota.github.io/docs/Commands). Some commands are supported by all tasmota devices, but others are device specific the command MP3Play for example will play a song on a mp3 player running on Tasmota, and obviously won't have any effect on a smart plug. 

## Telemetry

The blueprint sends one telemetry input showing if the device is on or off. There is much more telemetry data available, you should probably modify the example for your own use case. 
