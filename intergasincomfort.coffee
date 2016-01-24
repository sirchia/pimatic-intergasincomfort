module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  Lan2RF = require './lib/lan2rf'
  M = env.matcher
  settled = (promise) -> Promise.settle([promise])

  class IntergasIncomfort extends env.plugins.Plugin
 
    init: (app, @framework, @config) =>

      # Promise that is resolved when the connection is established
      @_lastAction = new Promise( (resolve, reject) =>
        @lan2rf = new Lan2RF(@config.host)
        @lan2rf.once("connected", =>
          if @config.debug
            env.logger.debug "Connected, waiting for first update from cube"
          @lan2rf.once("update", resolve)
        )
        @lan2rf.once('error', reject)
        return
      ).timeout(60000).catch( (error) ->
        env.logger.error "Error on connecting to Lan2RF gateway: #{error.message}"
        env.logger.debug error.stack
        return
      )

      @lan2rf.on('response', (res) =>
        if @config.debug
          env.logger.debug "Response: ", res
      )

      @lan2rf.on("update", (data) =>
        if @config.debug
          env.logger.debug "got update", data
      )

      @lan2rf.on('error', (error) =>
        env.logger.error "connection error: #{error}"
        env.logger.debug error.stack
      )

      deviceConfigDef = require("./device-config-schema")
      @framework.deviceManager.registerDeviceClass("IntergasIncomfortHeatingThermostat", {
        configDef: deviceConfigDef.IntergasIncomfortHeatingThermostat,
        createCallback: (config, lastState) -> new IntergasIncomfortHeatingThermostat(config, lastState)
      })

    setTemperatureSetpoint: (rfAddress, mode, value) ->
      @_lastAction = settled(@_lastAction).then( => 
        @lan2rf.setTemperatureAsync(rfAddress, mode, value) 
      )
      return @_lastAction


  plugin = new IntergasIncomfort
 
  class IntergasIncomfortHeatingThermostat extends env.devices.HeatingThermostat

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_temperatureSetpoint = lastState?.temperatureSetpoint?.value
      @_mode = lastState?.mode?.value or "auto"
      @_battery = lastState?.battery?.value or "ok"
      @_lastSendTime = 0

      plugin.mc.on("update", (data) =>
        data = data[@config.rfAddress]
        if data?
          now = new Date().getTime()
          ###
          Give the cube some time to handle the changes. If we send new values to the cube
          we set _lastSendTime to the current time. We consider the values as succesfull set, when
          the command was not rejected. But the updates comming from the cube in the next 30
          seconds do not always reflect the updated values, therefore we ignoring the old values
          we got by the update message for 30 seconds. 

          In the case that the cube did not react to our the send commands, the values will be 
          overwritten with the internal state (old ones) of the cube after 30 seconds, because
          the update event is emitted by lan2rf periodically.
          ###
          if now - @_lastSendTime < 30*1000
            # only if values match, we are synced
            if data.setpoint is @_temperatureSetpoint and data.mode is @_mode
              @_setSynced(true)
          else
            # more then 30 seconds passed, set the values anyway
            @_setSetpoint(data.setpoint)
            @_setMode(data.mode)
            @_setSynced(true)
          @_setValve(data.valve)
          @_setBattery(data.battery)
        return
      )
      super()

    changeModeTo: (mode) ->
      temp = @_temperatureSetpoint
      if mode is "auto"
        temp = null
      return plugin.setTemperatureSetpoint(@config.rfAddress, mode, temp).then( =>
        @_lastSendTime = new Date().getTime()
        @_setSynced(false)
        @_setMode(mode)
      )
        
    changeTemperatureTo: (temperatureSetpoint) ->
      if @temperatureSetpoint is temperatureSetpoint then return
      return plugin.setTemperatureSetpoint(@config.rfAddress, @_mode, temperatureSetpoint).then( =>
        @_lastSendTime = new Date().getTime()
        @_setSynced(false)
        @_setSetpoint(temperatureSetpoint)
      )

  return plugin
