###*
#
# probemon adapter
###
'use strict'

requests = {}
_ = require "lodash"

OFFLINE_TIMEOUT = 1000*60*20

setOffline = (mac) ->
  requests[mac].online = false
  adapter.setState mac + '.online', val: false, ack: true

trackDevice = (deviceConfig) ->
  unless requests[deviceConfig.mac]
    requests[deviceConfig.mac] =
      lastSeen: +new Date
      online: true
      timeout: setTimeout (-> setOffline mac), OFFLINE_TIMEOUT
    adapter.setObject deviceConfig.name + '.online',
      type: 'state'
      common:
        name: 'online'
        type: 'boolean'
        role: 'indicator.reachable'
      native: {}

    adapter.setObject deviceConfig.name + '.lastSeen',
      type: 'state'
      common:
        name: 'lastSeen'
        type: 'date'
      native: {}
  else
    clearTimeout requests[deviceConfig.mac].timeout
    requests[deviceConfig.mac].timeout = setTimeout (-> setOffline mac), OFFLINE_TIMEOUT
    requests[deviceConfig.mac].lastSeen = +new Date
    requests[deviceConfig.mac].online = true

  adapter.setState deviceConfig.name + '.online', val: true, ack: true
  adapter.setState deviceConfig.name + '.lastSeen', val: +new Date, ack: true


handleProbeRequest = (mac) ->
  # check if device is set to track
  adapter.log.info "handle #{mac}"
  deviceConfig = _.find adapter.config.devices, (dev) -> dev.mac is mac
  if deviceConfig?
    trackDevice deviceConfig
  #else
    #if adapter.config.nsa_mode
  adapter.setState "nsamode.raw_proberequest", val: mac, ack: true






main = ->
  # The adapters config (in the instance object everything under the attribute "native") is accessible via
  # adapter.config:
  adapter.log.info 'creating pcap session'

  adapter.setObject "nsamode.raw_proberequest",
    type: 'state'
    common:
      name: 'raw_proberequest'
      type: 'string'
      role: 'info'
    native: {}


  pcap.createSession(adapter.config.interface, '(type mgt) and (type mgt subtype probe-req )').on 'packet', (raw_packet) ->
    #              console.log(pcap.decode.packet(raw_packet).payload);
    frame = pcap.decode.packet(raw_packet).payload.ieee802_11Frame
    #if frame.type == 0 and frame.subType == 4
    if frame.shost?
      handleProbeRequest frame.shost.toString()
    return

  # in this probemon all states changes inside the adapters namespace are subscribed
  adapter.subscribeStates '*'



pcap = require('pcap')
# you have to require the utils module and call adapter function
utils = require(__dirname + '/lib/utils')
# Get common adapter utils
# you have to call the adapter function and pass a options object
# name has to be set and has to be equal to adapters folder name and main file name excluding extension
# adapter will be restarted automatically every time as the configuration changed, e.g system.adapter.probemon.0
adapter = utils.adapter('probemon')
# is called when adapter shuts down - callback has to be called under any circumstances!
adapter.on 'unload', (callback) ->
  try
    adapter.log.info 'cleaned everything up...'
    callback()
  catch e
    callback()
  return
# sudo iw phy phy1 interface add mon0 type monitor
# sudo ifconfig wlan1 up
# sudo ifconfig mon0 up
# is called if a subscribed object changes
adapter.on 'objectChange', (id, obj) ->
  # Warning, obj can be null if it was deleted
  adapter.log.info 'objectChange ' + id + ' ' + JSON.stringify(obj)
  return
# is called if a subscribed state changes
adapter.on 'stateChange', (id, state) ->
  # Warning, state can be null if it was deleted
  adapter.log.info 'stateChange ' + id + ' ' + JSON.stringify(state)
  # you can use the ack flag to detect if it is status (true) or command (false)
  if state and !state.ack
    adapter.log.info 'ack is not set!'
  return
# is called when databases are connected and adapter received configuration.
# start here!
adapter.on 'ready', ->
  main()
  return
