module.exports = (env) ->

  Promise = env.require 'bluebird'
  Lan2RF = require './lib/lan2rf'
  settled = (promise) -> promise.reflect()

  class IntergasIncomfort extends env.plugins.Plugin
 
    init: (app, @framework, @config) =>
      deviceConfigDef = require("./device-config-schema")
      @_lastAction = Promise.resolve()
      @framework.deviceManager.registerDeviceClass("IntergasIncomfortHeatingThermostat", {
        configDef: deviceConfigDef.IntergasIncomfortHeatingThermostat,
        createCallback: (config, lastState) -> new IntergasIncomfortHeatingThermostat(config, lastState)
      })

      @framework.deviceManager.registerDeviceClass("IntergasIncomfortTemperatureSensor", {
        configDef: deviceConfigDef.IntergasIncomfortTemperatureSensor,
        createCallback: (config, lastState) -> new IntergasIncomfortTemperatureSensor(config, lastState)
      })
      @lan2RfMap = {}

    setTemperatureSetpoint: (lan2rf, value, roomId) ->
      @_lastAction = settled(@_lastAction).then( ->
        return lan2rf.setThermostatSetPoint(value, roomId)
      )
      return @_lastAction

    getLan2Rf: (connection) ->
      lan2RfKey = @_toLan2RfKey(connection)
      lan2Rf = @lan2RfMap[lan2RfKey]
      if lan2Rf?
        env.logger.debug "Re-using existing Lan2Rf gateway connection"
        if connection.updateInterval < lan2Rf.updateInterval
          env.logger.debug "Re-scheduling update interval to shorter interval of #{connection.updateInterval}ms"
          lan2Rf.rescheduleUpdates connection.updateInterval
      else
        env.logger.debug "Creating new Lan2Rf gateway connection"
        lan2Rf = new Lan2RF(connection)
        @lan2RfMap[lan2RfKey] = lan2Rf
      return lan2Rf

    _toLan2RfKey: (connection) ->
      return "#{connection.host}:#{connection.heaterId}"


  plugin = new IntergasIncomfort
 
  class IntergasIncomfortHeatingThermostat extends env.devices.HeatingThermostat

    attributes:
      temperatureSetpoint:
        label: "Temperature Setpoint"
        description: "The temp that should be set"
        type: "number"
        discrete: true
        unit: "°C"
#      valve:
#        description: "Position of the valve"
#        type: "number"
#        discrete: true
#        unit: "%"
      mode:
        description: "The current mode"
        type: "string"
        enum: ["auto", "manu", "boost"]
      pumpActive:
        description: "Boiler pump is active"
        type: "boolean"
      tapActive:
        description: "Hot water tap is active"
        type: "boolean"
      burnerActive:
        description: "Burner of boiler is active"
        type: "boolean"
      synced:
        description: "Pimatic and thermostat in sync"
        type: "boolean"


    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @debug = @config.connection.debug
      @roomNumber = @config.connection.roomId + 1
      @_mode = lastState?.mode?.value or "auto"

      # Promise that is resolved when the connection is established
      @_lastAction = new Promise( (resolve, reject) =>
        @lan2rf = plugin.getLan2Rf(@config.connection)
        if @debug
          env.logger.debug "Connected, waiting for first update from Lan2RF gateway for #{@id}"
        @lan2rf.once 'update', =>
          if @debug
            env.logger.debug "Received 1st update for #{@id}, connection successful"
          resolve()

        @lan2rf.once 'error', reject
      ).timeout(60000).catch( (error) =>
        env.logger.error "Error on connecting to Lan2RF gateway for #{@id}: #{error}"
        env.logger.debug error.stack
      )

      @lan2rf.on('error', (error) =>
        env.logger.error "connection error for #{@id}: #{error}"
        env.logger.debug error.stack
      )

      @lan2rf.on('update', (data) =>
        if @debug
          env.logger.debug "got update for #{@id}", data
        if data?
#          @_setValve(data.valve)
          @_setSynced(data["room_set_ovr_#{@roomNumber}"] is data["room_temp_set_#{@roomNumber}"])
          @_setSetpoint(data["room_set_ovr_#{@roomNumber}"])
          @_setPumpActive(data.pump_active)
          @_setTapActive(data.tap_function_active)
          @_setBurnerActive(data.burner_active)
      )
      super()

    getPumpActive: () -> Promise.resolve(@_pumpActive)
    getTapActive: () -> Promise.resolve(@_tapActive)
    getBurnerActive: () -> Promise.resolve(@_burnerActive)

    _setPumpActive: (pumpActive) ->
      if pumpActive is @_pumpActive then return
      @_pumpActive = pumpActive
      @emit "pumpActive", @_pumpActive

    _setTapActive: (tapActive) ->
      if tapActive is @_tapActive then return
      @_tapActive = tapActive
      @emit "tapActive", @_tapActive

    _setBurnerActive: (burnerActive) ->
      if burnerActive is @_burnerActive then return
      @_burnerActive = burnerActive
      @emit "burnerActive", @_burnerActive

    changeModeTo: (mode) ->
      @_setMode(mode)

    changeTemperatureTo: (temperatureSetpoint) ->
      if @temperatureSetpoint is temperatureSetpoint then return
      return plugin.setTemperatureSetpoint(@lan2rf, temperatureSetpoint, @roomId).then( =>
        @_setSynced(false)
        @_setSetpoint(temperatureSetpoint)
      )

  class IntergasIncomfortTemperatureSensor extends env.devices.TemperatureSensor

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @debug = @config.connection.debug
      @roomNumber = @config.connection.roomId + 1
      @_temperature = lastState?.temperature?.value

      # Promise that is resolved when the connection is established
      @_lastAction = new Promise( (resolve, reject) =>
        @lan2rf = plugin.getLan2Rf(@config.connection)
        if @debug
          env.logger.debug "Connected, waiting for first update from Lan2RF gateway for #{@id}"
        @lan2rf.once 'update', =>
          if @debug
            env.logger.debug "Received 1st update for #{@id}, connection successful"
          resolve()

        @lan2rf.once 'error', reject
      ).timeout(60000).catch( (error) =>
        env.logger.error "Error on connecting to Lan2RF gateway for #{@id}: #{error.message}"
        env.logger.debug error.stack
      )

      @lan2rf.on('error', (error) =>
        env.logger.error "connection error for #{@id}: #{error}"
        env.logger.debug error.stack
      )

      @lan2rf.on('update', (data) =>
        if @debug
          env.logger.debug "got update for #{@id}", data
        if data?
          @_setTemperature(data['room_temp_'+@roomNumber])
      )
      super()

  return plugin
