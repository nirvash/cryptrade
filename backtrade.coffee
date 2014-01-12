require "underscore"
fs = require "fs"
CoffeeScript = require 'coffee-script'
CSON = require 'cson'
basename = require('path').basename
Trader = require './trader'
logger = require 'winston'
Fiber = require 'fibers'

logger.remove logger.transports.Console
logger.add logger.transports.Console,{level:'info',colorize:true,timestamp:true}

# CONFIG
source = "./j9YKW6GtMSnePrjTK.coffee"
data = require "./j9YKW6GtMSnePrjTK.json"
pair = "btc_usd"
config = CSON.parseFileSync './backtest_config.cson'

# Deep copy
# Taken from http://coffeescriptcookbook.com/chapters/classes_and_objects/cloning
clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime())

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags)

  newInstance = new obj.constructor()

  for key of obj
    newInstance[key] = clone obj[key]

  return newInstance


# THE CODE
instrument = data[pair]
data.instruments[0] = instrument # A fix for when it's wrong

length_initial = 248
length_end = instrument.open.length

console.log "initial: #{length_initial},  end: #{length_end}"

# Read the script, and compile it
code = fs.readFileSync source,
  encoding: 'utf8'
name = basename source,'.coffee'

script = CoffeeScript.compile code,
  bare:true

# Intialize a trader instance, no key
trader = new Trader name,config,null,script

# Ready the initial data
elems = ["open", "close", "high", "low", "volumes", "ticks"]


temp = clone(data) # We don't want to ruin the original data
temp_instrument = temp[pair]

for el in elems
  t = instrument[el]
  temp_instrument[el] = t[...length_initial]

last_i = temp_instrument.close.length - 1 # Asserted that all arrays are of equal length

temp_instrument["price"] = temp_instrument.close[last_i]
temp_instrument["volume"] = temp_instrument.volumes[last_i]
temp.at = temp_instrument.ticks[last_i].at

Fiber =>
  # Initialize the trader with the initial data
  bars = clone temp_instrument.ticks
  trader.init(bars)


  # Gradually extend the object
  for i in [length_initial...length_end-1]
  #for i in [length_initial...length_initial+1]
    # Array stuff
    for el in elems
      a = instrument[el]
      b = temp_instrument[el]

      o = clone(a[i])
      b.push(o)


    # Non-array stuff
    last_i = temp_instrument.close.length - 1 # Asserted that all arrays are of equal length
  #  console.log "i: #{i}, last_i: #{last_i}"

    temp_instrument["price"] = temp_instrument.close[last_i]
    temp_instrument["volume"] = temp_instrument.volumes[last_i]
    temp.at = temp_instrument.ticks[last_i].at

    # Trader gets the last bar = tick
    bar = temp_instrument.ticks[last_i]
    bar.instrument = pair
    trader.handle bar
.run()
