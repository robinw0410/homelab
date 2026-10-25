# Rack fan controller

ESP32 in the rack that measures temperature and humidity with an SHT31-D and drives a 120 mm PWM fan
along a temperature curve. Reports rack temperature, humidity, fan speed and fan state to Home Assistant
(Rack section of the server view in the [dashboard](../../home-assistant/dashboard.yaml)).
Runs ESPHome with the ESP-IDF framework.

**Status:** deployed, the fan is controlled automatically.

## Parts

- diymore ESP32 dev board
- SHT31-D temperature/humidity sensor (I2C)
- Noctua NF-P12 redux-1700 PWM (4-pin)
- 12 V / 2 A power supply for the fan
- 10 kΩ pull-up resistor on the tachometer line

## Wiring

| Function | ESP32 pin | Notes |
|---|---|---|
| I2C SDA | GPIO21 | SHT31-D at address `0x44`, read every 15 s |
| I2C SCL | GPIO22 | I2C bus scan enabled |
| PWM | GPIO25 | LEDC output, 25 kHz (Intel 4-pin fan spec) |
| Tacho | GPIO26 | Pulse counter, internal pull-up enabled plus external 10 kΩ pull-up; the fan gives 2 pulses per revolution, so the count is multiplied by 0.5 |

The tacho value is published as "pulses/min"; after the ×0.5 filter it equals revolutions per minute.

## Control logic

Evaluated every 15 s in an `interval` lambda in [`rack-fan-controller.yaml`](rack-fan-controller.yaml):

| Condition | Fan |
|---|---|
| Fan off and temperature < 35 °C | Stays off |
| Fan off and temperature ≥ 35 °C | On at 20 % |
| Fan on, 30–35 °C | 20 % |
| Fan on, 35–45 °C | Linear from 20 % to 100 % |
| Fan on, ≥ 45 °C | 100 % |
| Fan on and temperature < 30 °C | Off |
| Sensor value invalid (`NaN`) | **Failsafe:** 50 % |

- **Hysteresis:** switches on at 35 °C, off only below 30 °C, so the fan doesn't toggle around one threshold.
- **Failsafe:** if the SHT31-D delivers no valid reading, the fan runs at 50 % regardless of the curve.
- The on/off state is not restored after a reboot; the controller starts with the fan off and re-evaluates
  on the next 15 s tick.

## Configuration

[`rack-fan-controller.yaml`](rack-fan-controller.yaml). Wi-Fi credentials, the API encryption key and the
fallback hotspot password come from `secrets.yaml` (git-ignored), see [`secrets.example.yaml`](secrets.example.yaml).

STL files and photos will follow.
