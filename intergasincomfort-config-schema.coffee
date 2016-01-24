module.exports = {
  title: "intergasinfcomfort-thermostat config"
  type: "object"
  properties:
    host:
      description: "The IP of the Lan2RF Gateway"
      type: "string"
      default: "127.0.0.1"
    debug:
      description: "Output update message from Lan2RF and additional infos"
      type: "boolean"
      default: true
}