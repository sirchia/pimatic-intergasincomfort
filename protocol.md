### list of heaters
curl -X GET http://192.168.1.11/heaterlist.json

example output:
{"heaterlist":["1403c004675",null,null,null,null,null,null,null]}

index in this array used in subsequent queries


### data.json
export HEATERLIST_INDEX=0
curl -X GET http://192.168.1.11/data.json?heater=${HEATERLIST_INDEX}

* **nodenr**
  TODO - Node number
  
* **ch_temp_lsb, ch_temp_msb**
  Heater temperature ((msb*256+lsb)/100.0)
  
* **tap_temp_lsb, tap_temp_msb**
  Tapwater temperature ((msb*256+lsb)/100.0)
  
* **ch_pressure_lsb, ch_pressure_msb**
  Water pressure on pipes ((msb*256+lsb)/100.0)
  
* **room_temp_1_lsb, room_temp_1_msb**
  Current room temperature measured by thermostat ((msb*256+lsb)/100.0)
  
* **room_temp_set_1_lsb, room_temp_set_1_msb**
  Currently set temperature on boiler, manually on thermostat or after change by incomfort has been processed ((msb*256+lsb)/100.0)
  
* **room_set_ovr_1_lsb, room_set_ovr_1_msb**
  Currently set temperature through incomfort ((msb*256+lsb)/100.0)
  
* **room_temp_2_lsb, room_temp_2_msb**
  See room 1, not used in 'normal' setup? ((msb*256+lsb)/100.0)
  
* **room_temp_set_2_lsb, room_temp_set_2_msb**
  See room 1, not used in 'normal' setup? ((msb*256+lsb)/100.0)
  
* **room_set_ovr_2_lsb, room_set_ovr_2_msb**
  See room 1, not used in 'normal' setup? ((msb*256+lsb)/100.0)
  
* **displ_code**
  85 -> sensortest
  170 -> service
  204 -> tapwater
  51 -> tapwater int.
  240 -> boiler int.
  15 -> boiler ext.
  153 -> postrun boiler
  102 -> central heating
  0 -> opentherm
  255 -> buffer
  24 -> frost
  231 -> postrun ch
  126 -> standby
  37 -> central heating 
  
* **IO**
  lockout &= 1 -> Error with displ_code as message
  pump &= 2
  tapfunction &= 4
  burner &= 8
  
* **serial_year**
  Build date of Lan2RF Gateway software?
  
* **serial_month**
  Build date of Lan2RF Gateway software?
  
* **serial_line**
  TODO  
  
* **serial_sn1**
  TODO
  
* **serial_sn2**
  TODO
  
* **serial_sn3**
  TODO
  
* **rf_message_rssi**
  TODO
  
* **rfstatus_cntr**
  TODO

### Set new setpoint
export HEATERLIST_INDEX=0
export ROOM_INDEX=0 #0=room 1, 1 = room 2
export SET_POINT=120 #=(desired temp - 5)*10
curl -X GET http://192.168.1.11/data.json?heater=${HEATERLIST_INDEX}&setpoint=${SETPOINT}&thermostat=${ROOM_INDEX}

