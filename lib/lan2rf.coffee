Promise = require 'bluebird'
events = require 'events'
http = require 'http'

#settled = (promise) -> Promise.settle([promise])

class Lan2RF extends events.EventEmitter
  @_DISPLAY_CODES: {
    85: 'Zelftest'
    170: 'Service'
    204: 'Warmwater'
    51: 'Warmwater int.'
    240: 'Boiler int.'
    15: 'Boiler ext.'
    153: 'Nadraaien boiler'
    102: 'CV'
    0: 'Opentherm'
    255: 'Buffer'
    24: 'Vorst'
    231: 'Nadraaien CV'
    126: 'Gereed'
    37: 'CV RF'
  }

  constructor: (connection) ->
    @host = connection.host
    @heaterId = connection.heaterId

    @getDataRequest = {
      host: @host,
      path: "/data.json?heater=#{@heaterId}"
    }

    # start periodic updates update
    @rescheduleUpdates connection.updateInterval

  rescheduleUpdates: (updateInterval) ->
    @updateInterval = updateInterval
    if @_periodicUpdateTimerId?
      clearTimeout @_periodicUpdateTimerId
    @_periodicUpdateFromLan2RF()

  updateFromLan2RF: ->
    @_processUrlJSONAsync(@getDataRequest)

  setThermostatSetPoint: (temperature, roomId) ->
    setpointPath = "/data.json?heater=#{@heaterId}&setpoint=#{(temperature - 5) * 10}&thermostat=#{roomId}"
    return @_processUrlJSONAsync({host: @host, path: setpointPath}).then( =>
      Promise.resolve __("Incomfort gateway passed setpoint %s C to the room thermostat", temperature)
    )

  _processUrlJSONAsync: (request) ->
    return new Promise((resolve, reject) =>
      http.get(request, (res) =>
        body = ''

        res.on 'data', (chunk) =>
          body += chunk

        res.on 'end', =>
          try
            data = JSON.parse body
            parsedData = @_decode data
            @emit 'update', parsedData
            resolve()
          catch error
            reject error

        res.on 'error', (e) =>
          @emit 'error', e
          reject e
      ).on('error', (e) =>
        console.log "Got error: #{e.message}"
        @emit 'error', e
        reject e
      )
    )

  _periodicUpdateFromLan2RF: =>
    @updateFromLan2RF()
    @_periodicUpdateTimerId = setTimeout @_periodicUpdateFromLan2RF, @updateInterval

  _decode: (data) ->
    result = {}
    for key, value of data
      if key.indexOf('_lsb') > -1
        newKey = key.slice 0, -4
        newValue = (data[(newKey + '_msb')] * 256 + value) / 100.0
        result[newKey] = newValue unless newValue is 327.67
      else if key is 'displ_code'
        result[key] = Lan2RF._DISPLAY_CODES[value] ? 'unknown'
      else if key is 'IO'
        result.lock_out = (value &  1) == 1
        result.pump_active = (value &  2) == 2
        result.tap_function_active = (value &  4) == 4
        result.burner_active = (value &  8) == 8
      else result[key] = value unless key.indexOf('_msb') > -1
    if result.lock_out
      result.error = "Error: #{result.displ_code}"
      result.displ_code = "Error: #{data.displ_code}"
    
    #console.log(result)
    return result

module.exports = Lan2RF