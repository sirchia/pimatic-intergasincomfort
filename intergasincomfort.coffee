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
        env.logger.debug "Setting requested thermostat setpoint to #{value}"
        return lan2rf.setThermostatSetPoint(value, roomId).then( (result) => Promise.resolve result )
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
        type: "string"
      tapActive:
        description: "Hot water tap is active"
        type: "string"
      burnerActive:
        description: "Burner of boiler is active"
        type: "string"
      synced:
        description: "Pimatic and thermostat in sync"
        type: "boolean"
      heaterStatus:
        description: "Central Heater status"
        type: "string"
        discrete: true
      waterPressure:
        description: "Central Heater pressure"
        type: "number"
        discrete: true
        unit: "bar"
      heaterTemperature:
        description: "Central Heater temperature"
        type: "number"
        discrete: true
        unit: "°C"
      tapTemperature:
        description: "Tap water temperature"
        type: "number"
        discrete: true
        unit: "°C"
      signalStrength:
        description: "RF Signal Strength"
        type: "number"
        discrete: true
        unit: "%"


    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @debug = @config.connection.debug
      @roomNumber = @config.connection.roomId + 1
      @_mode = lastState?.mode?.value or "auto"
      
      @_stateToString = {
        true: "Aan"
        false: "Uit"
      }
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

      @lan2rf.on('error', @errorHandler = (error) =>
        env.logger.error "connection error for #{@id}: #{error}"
        env.logger.debug error.stack
      )

      @lan2rf.on('update', @updateHandler = (data) =>
        if @debug
          env.logger.debug "got update for #{@id}", data
        if data?
#          @_setValve(data.valve)
          currentRoomSetpoint = data["room_temp_set_#{@roomNumber}"]

          if currentRoomSetpoint == @_temperatureSetpoint
            #Lan2RF setpont is the same as ours, reset any outstanding setpoint modifications
            if @lastSetpointTime?
              env.logger.info __("Room thermostat processed the new temperature setting of %s C", currentRoomSetpoint)
              @lastSetpointTime = null
          else
            # Lan2RF setpoint differs from ours
            if @lastSetpointTime?
              # We had a setpoint outstanding, check the time
              if (new Date() - @lastSetpointTime) > 300000
                # It's been longer than 5 minutes ago, give up and accept the incoming change
                env.logger.debug "Accepting setpoint #{currentRoomSetpoint} from Lan2RF after timeout, external change?"
                @lastSetpointTime = null
                @_setSetpoint(currentRoomSetpoint)
              else
                # Timeout hasn't passed yet, keep hoping our values are being processed
                env.logger.debug "Rejecting setpoint #{currentRoomSetpoint} as we are waiting for our own setpont to be processed"
            else
              # We did not have any outstanding setpoint change, just accept the new value
              env.logger.debug "Accepting current room setpoint #{currentRoomSetpoint} from Lan2RF"
              @_setSetpoint(currentRoomSetpoint)

          @_setSynced(currentRoomSetpoint == @_temperatureSetpoint)
          @_setPumpActive(data.pump_active)
          @_setTapActive(data.tap_function_active)
          @_setBurnerActive(data.burner_active)
          @_setHeaterStatus(data.displ_code)
          @_setWaterPressure(data.ch_pressure)
          @_setHeaterTemperature(data.ch_temp)
          @_setTapTemperature(data.tap_temp)
          @_setSignalStrength(data.rf_message_rssi)
      )
      super()

    destroy: () ->
      @lan2rf.removeListener 'error', @errorHandler
      @lan2rf.removeListener 'update', @updateHandler
      super()

    getPumpActive: () -> Promise.resolve(@_pumpActive)
    getTapActive: () -> Promise.resolve(@_tapActive)
    getBurnerActive: () -> Promise.resolve(@_burnerActive)
    getHeaterStatus: () -> Promise.resolve(@_heaterStatus)
    getWaterPressure: () -> Promise.resolve(@_waterPressure)
    getHeaterTemperature: () -> Promise.resolve(@_heaterTemperature)
    getTapTemperature: () -> Promise.resolve(@_tapTemperature)
    getSignalStrength: () -> Promise.resolve(@_signalStrength)

    _setPumpActive: (pumpActive) ->
      if pumpActive is @_pumpActive then return
      @_pumpActive = @_stateToString[pumpActive]
      @emit "pumpActive", @_pumpActive

    _setTapActive: (tapActive) ->
      if tapActive is @_tapActive then return
      @_tapActive = @_stateToString[tapActive]
      @emit "tapActive", @_tapActive

    _setBurnerActive: (burnerActive) ->
      if burnerActive is @_burnerActive then return
      @_burnerActive = @_stateToString[burnerActive]
      @emit "burnerActive", @_burnerActive

    _setHeaterStatus: (heaterStatus) ->
      if heaterStatus is @_heaterStatus then return
      @_heaterStatus = heaterStatus
      @emit "heaterStatus", @_heaterStatus

    _setWaterPressure: (waterPressure) ->
      if waterPressure is @_waterPressure then return
      @_waterPressure = waterPressure
      @emit "waterPressure", @_waterPressure

    _setHeaterTemperature: (heaterTemperature) ->
      if heaterTemperature is @_heaterTemperature then return
      @_heaterTemperature = heaterTemperature
      @emit "heaterTemperature", @_heaterTemperature

    _setTapTemperature: (tapTemperature) ->
      if tapTemperature is @_tapTemperature then return
      @_tapTemperature = tapTemperature
      @emit "tapTemperature", @_tapTemperature

    _setSignalStrength: (signalStrength) ->
      if signalStrength is @_signalStrength then return
      @_signalStrength = signalStrength
      @emit "signalStrength", @_signalStrength

    changeModeTo: (mode) ->
      @_setMode(mode)

    changeTemperatureTo: (temperatureSetpoint) ->
      if @_temperatureSetpoint is temperatureSetpoint
        Promise.resolve __("Temperature has already been set to %s C", temperatureSetpoint)
      else
        return plugin.setTemperatureSetpoint(@lan2rf, temperatureSetpoint, @roomId).then( (result)=>
          @lastSetpointTime = new Date()
          @_setSynced(false)
          @_setSetpoint(temperatureSetpoint)
          env.logger.info result
          Promise.resolve result
          
        ).catch( (error) =>
          env.loggger.error error.stack
          Promise.reject(new Error(__("Error setting temperature to %s", temperatureSetpoint)))
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

      @lan2rf.on('error', @errorHandler = (error) =>
        env.logger.error "connection error for #{@id}: #{error}"
        env.logger.debug error.stack
      )

      @lan2rf.on('update', @updateHandler = (data) =>
        if @debug
          env.logger.debug "got update for #{@id}", data
        if data?
          @_setTemperature(data['room_temp_'+@roomNumber])
      )
      super()

    destroy: () ->
      @lan2rf.removeListener 'error', @errorHandler
      @lan2rf.removeListener 'update', @updateHandler
      super()

  return plugin
