Pimatic Intergas Incomfort plugin
=======================

Plugin to control an Intergas central heating boiler through Incomfort Lan2RF gateway

Configuration
-------------
You can load the plugin by editing your `config.json` to include (host = Max!Cube IP port=Max!Cube Port (default:62910)):

````json
{ 
   "plugin": "intergasincomfort",
   "host": "192.168.X.X"
}
````

Use the debug output in pimatic to find out the rfAddress of the devices. Sample debug output:

````
09:04:42.165 [pimatic-intergasincomfort] got update
09:04:42.168 [pimatic-intergasincomfort] { type: 'Heating Thermostat',
09:04:42.168 [pimatic-intergasincomfort]>  address: '12345cf', <-- rfAddress
09:04:42.168 [pimatic-intergasincomfort]>  serial: 'KEQ04116',
09:04:42.168 [pimatic-intergasincomfort]>  name: 'Heizung',
09:04:42.168 [pimatic-intergasincomfort]>  roomId: 1,
09:04:42.168 [pimatic-intergasincomfort]>  comfortTemperature: 23,
09:04:42.168 [pimatic-intergasincomfort]>  ecoTemperature: 16.5,
09:04:42.168 [pimatic-intergasincomfort]>  maxTemperature: 30.5,
09:04:42.168 [pimatic-intergasincomfort]>  minTemperature: 4.5,
09:04:42.168 [pimatic-intergasincomfort]>  temperatureOffset: 3.5,
09:04:42.168 [pimatic-intergasincomfort]>  windowOpenTemperature: 12,
09:04:42.168 [pimatic-intergasincomfort]>  valve: 0,
09:04:42.168 [pimatic-intergasincomfort]>  setpoint: 17,
09:04:42.168 [pimatic-intergasincomfort]>  battery: 'ok',
09:04:42.168 [pimatic-intergasincomfort]>  mode: 'manu' }
````
  
Thermostats can be defined by adding them to the `devices` section in the config file.
Set the `class` attribute to `MaxHeatingThermostat`. For example:

```json
{ 
  "id": "bathroomLeft",
  "class": "MaxHeatingThermostat", 
  "name": "Bathroom Radiator left",
  "rfAddress": "12345cf",
  "comfyTemp": 23.0,
  "ecoTemp": 17.5,
}
```

For contact sensors add this config:

```json
{ 
  "id": "window-bathroom",
  "class": "MaxContactSensor", 
  "name": "Bathroom Window",
  "rfAddress": "12345df"
}
```
