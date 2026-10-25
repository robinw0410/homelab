# Room sensor

ESP32 with an SHT31-D that reports temperature and humidity of the living room to Home Assistant
(Klima section of the [dashboard](../../home-assistant/dashboard.yaml)). Runs ESPHome with the ESP-IDF framework.

**Status:** deployed

## Parts

- diymore ESP32 dev board
- SHT31-D temperature/humidity sensor (I2C)
- 3D-printed enclosure (see below)

## Wiring

| Function | ESP32 pin | Notes |
|---|---|---|
| I2C SDA | GPIO21 | SHT31-D at address `0x44` |
| I2C SCL | GPIO22 | |

## Enclosure

Two-part case, STL files (GitHub shows a 3D preview when you open them):

- [`esp32_temperature_bottom.stl`](esp32_temperature_bottom.stl)
- [`esp32_temperature_cover.stl`](esp32_temperature_cover.stl)

## Configuration

[`sensor.yaml`](sensor.yaml). Wi-Fi credentials, the API encryption key and the fallback hotspot password
come from `secrets.yaml` (git-ignored), see [`secrets.example.yaml`](secrets.example.yaml).

Photos will follow.
