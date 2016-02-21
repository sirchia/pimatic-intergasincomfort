module.exports = {
  title: "intergasincomfort-thermostat device config schemas"
  IntergasIncomfortHeatingThermostat: {
    title: "IntergasIncomfortHeatingThermostat config options"
    type: "object"
    properties:
      connection:
        description: "All Lan2RF connection settings"
        type: "object"
        properties:
          host:
            description: "The IP address of the Lan2RF Gateway"
            type: "string"
          updateInterval:
            description: "The amount of ms between each update pull from the Lan2RF Gateway"
            type: "integer"
            default: 60000
          heaterId:
            description: "The ID of the boiler connected to the Lan2RF gateway"
            type: "integer"
            default: 0
          roomId:
            description: "The room ID of the thermostat, may be 0 or 1"
            type: "integer"
            default: 0
          debug:
            description: "Output update message from Lan2RF and additional infos"
            type: "boolean"
            default: false
      comfyTemp:
        description: "The defined comfy temperature"
        type: "number"
        default: 21
      ecoTemp:
        description: "The defined eco mode temperature"
        type: "number"
        default: 17
      guiShowModeControl:
        description: "Show the mode buttons in the gui"
        type: "boolean"
        default: true
      guiShowPresetControl:
        description: "Show the preset temperatures in the gui"
        type: "boolean"
        default: true
      guiShowTemperatureInput:
        description: "Show the temperature input spinbox in the gui"
        type: "boolean"
        default: true
      guiShowValvePosition:
        description: "Show the valve position in the gui"
        type: "boolean"
        default: true
  },
  IntergasIncomfortTemperatureSensor: {
    title: "IntergasIncomfortTemperatureSensor config options"
    type: "object"
    properties:
      connection:
        description: "All Lan2RF connection settings"
        type: "object"
        properties:
          host:
            description: "The IP address of the Lan2RF Gateway"
            type: "string"
          updateInterval:
            description: "The amount of ms between each update pull from the Lan2RF Gateway"
            type: "integer"
            default: 60000
          heaterId:
            description: "The ID of the boiler connected to the Lan2RF gateway"
            type: "integer"
            default: 0
          roomId:
            description: "The room ID of the temperature sensor, may be 0 or 1"
            type: "integer"
            default: 0
          debug:
            description: "Output update message from Lan2RF and additional infos"
            type: "boolean"
            default: false
  }
}
