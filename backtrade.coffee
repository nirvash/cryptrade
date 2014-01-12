require "underscore"
fs = require "fs"
CoffeeScript = require 'coffee-script'
CSON = require 'cson'
basename = require('path').basename
Trader = require './trader'
logger = require 'winston'
Fiber = require 'fibers'
deepclone = require('./utils').deepclone

# TODO: Also make logger log to file? Although not really necessary for backtesting
logger.remove logger.transports.Console
logger.add logger.transports.Console,{level:'info',colorize:true,timestamp:true}


if require.main == module
  program = require('commander')
  program
    .usage('[options] <filename>')
    .option('-c,--config [value]','Load configuration file')
    .option('-i,--instrument [value]','Trade instrument (ex. btc_usd)')
    .option('-s,--initial [value]','Number of trades that are used for initialization (ex. 248)')
    .parse process.argv

  config = CSON.parseFileSync './backtest_config.cson'

  if program.config?
    logger.info "Loading configuration file configs/#{program.config}.cson.."
    anotherConfig = CSON.parseFileSync 'configs/'+program.config+'.cson'
    config = _.extend config,anotherConfig

  if program.args.length > 1
    logger.error "Too many arguments"
    process.exit 1

  if program.args.length < 1
    logger.error "Filename to trader source not specified"
    process.exit 1

  source = program.args[0]
  code = fs.readFileSync source,
    encoding: 'utf8'
  name = basename source,'.coffee'
  unless code?
    logger.error "Unable load source code from #{source}"
    process.exit 1

  # Load trade data
  # TODO: Use csv data, and let the user specify platform (mtgox,btce) and start/end times
  datafile = basename(source,'.coffee') + ".json"
  data = fs.readFileSync datafile,
    encoding: 'utf8'
  unless data?
    logger.error "Unable load trade data from #{datafile}"
    process.exit 1
  data = JSON.parse(data)

  # Configuration of instrument
  config.instrument = program.instrument or config.instrument or 'btc_usd'
  config.init_data_length = program.initial or config.init_data_length or 250

  script = CoffeeScript.compile code,
    bare:true
  logger.info 'Starting backtest...'

  # Intialize a trader instance, no key
  trader = new Trader name,config,null,script

  # Ready the initial data
  elems = ["open", "close", "high", "low", "volumes", "ticks"]

  instrument = data[config.instrument]
  data.instruments[0] = instrument # Fix the reference

  length_end = instrument.open.length

  temp = deepclone(data) # We don't want to ruin the original data
  temp_instrument = temp[config.instrument]

  for el in elems
    t = instrument[el]
    temp_instrument[el] = t[...config.init_data_length]

  last_i = temp_instrument.close.length - 1 # Asserted that all arrays are of equal length

  temp_instrument["price"] = temp_instrument.close[last_i]
  temp_instrument["volume"] = temp_instrument.volumes[last_i]
  temp.at = temp_instrument.ticks[last_i].at

  Fiber =>
    # Initialize the trader with the initial data
    bars = deepclone temp_instrument.ticks
    trader.init(bars)


    # Gradually extend the object
    for i in [config.init_data_length...length_end-1]
    #for i in [length_initial...length_initial+1]
      # Array stuff
      for el in elems
        a = instrument[el]
        b = temp_instrument[el]

        o = deepclone(a[i])
        b.push(o)


      # Non-array stuff
      last_i = temp_instrument.close.length - 1 # Asserted that all arrays are of equal length
    #  console.log "i: #{i}, last_i: #{last_i}"

      temp_instrument["price"] = temp_instrument.close[last_i]
      temp_instrument["volume"] = temp_instrument.volumes[last_i]
      temp.at = temp_instrument.ticks[last_i].at

      # Trader gets the last bar = tick
      bar = temp_instrument.ticks[last_i]
      bar.instrument = config.instrument
      trader.handle bar
  .run()
