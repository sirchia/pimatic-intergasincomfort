Pimatic Intergas Incomfort plugin
=======================

Plugin to control an Intergas central heating boiler through Incomfort Lan2RF gateway

Configuration
-------------
You can load the plugin by editing your `config.json` to include it:

````json
{ 
   "plugin": "intergasincomfort"
}
````

Thermostats and temperature sensors can be defined by adding them to the `devices` section in the config file.
For all configuration options see [device-config-schema](device-config-schema.coffee)

Set the `class` attribute to `IntergasIncomfortHeatingThermostat`. For example:

```json
{
  "id": "thermostat",
  "name": "Thermostat",
  "class": "IntergasIncomfortHeatingThermostat",
  "connection": {
    "host": "192.168.1.11",
  },
  "comfyTemp": 21,
  "ecoTemp": 17
}
```

For the temperature sensors add this config:

```json
{
  "id": "roomTemperature",
  "name": "Current room temperature",
  "class": "IntergasIncomfortTemperatureSensor",
  "connection": {
    "host": "192.168.1.11",
  }
}
```
