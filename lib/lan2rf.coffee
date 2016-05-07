Promise = require 'bluebird'
events = require 'events'
http = require 'http'

#settled = (promise) -> Promise.settle([promise])

class Lan2RF extends events.EventEmitter
  @_DISPLAY_CODES: {
    85: 'sensortest'
    170: 'service'
    204: 'tapwater'
    51: 'tapwater int.'
    240: 'boiler int.'
    15: 'boiler ext.'
    153: 'postrun boiler'
    102: 'central heating'
    0: 'opentherm'
    255: 'buffer'
    24: 'frost'
    231: 'postrun ch'
    126: 'standby'
    37: 'central heating'
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
    @_processUrlJSONAsync({host: @host, path: setpointPath})

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

    result.error = "Error: #{result.displ_code}" if result.lock_out

    return result

module.exports = Lan2RF