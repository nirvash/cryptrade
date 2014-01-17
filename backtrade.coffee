require "underscore"
fs = require "fs"
CoffeeScript = require 'coffee-script'
CSON = require 'cson'
io = require('socket.io-client')
basename = require('path').basename
Trader = require './trader'
logger = require 'winston'
Fiber = require 'fibers'
version = require('./package.json').version

# TODO: Also make logger log to file? Although not really necessary for backtesting
logger.remove logger.transports.Console
logger.add logger.transports.Console,{level:'info',colorize:true,timestamp:true}

if require.main == module
  program = require('commander')
  program
    .usage('[options] <filename>')
    .option('-c,--config [value]','Load configuration file')
    .option('-p,--platform [value]','Trade at specified platform')
    .option('-i,--instrument [value]','Trade instrument (ex. btc_usd)')
    .option('-s,--initial [value]','Number of trades that are used for initialization (ex. 248)',parseInt)
    .option('-b,--balance <asset,curr>','Initial balances of trade instrument (ex. 0,5000)',(val)->val.split(',').map(Number))
    .option('-f,--fee [value]','Fee on every trade in percent (ex. 0.2)',parseFloat)
    .option('-a,--add_length [value]','Additional initial periods to include (default: 100)',parseInt)
    .parse process.argv

  #Configuration initialization
  config = CSON.parseFileSync './config.cson'
  keys = CSON.parseFileSync 'keys.cson'
  unless keys?
    logger.error 'Unable to open keys.cson'
    process.exit 1
  config.instrument = program.instrument or config.instrument
  config.init_data_length = program.initial or config.init_data_length
  if program.balance?
     for x,i in config.instrument.split('_')
        pl.initial_balance[x] = program.balance[i]
  #This variable ensures an accurate backtest, by including a set amount of periods in the intial backtest. Should be at least equal to the period your longest indicator uses. Eg. EMA(200) should include at least 200 for add_length.
  add_length = program.add_length or 100

  # TODO: make this a separate option.
  #       That way, when the user does not have to specify the trade data

  # TODO: Cannot simulate the check order interval just yet. See trader.coffee
  config.check_order_interval = 0

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
  logger.info 'Connecting to data provider..'
  client = io.connect config.data_provider, config.socket_io
  trader = undefined
  client.socket.on 'connect', ->
    logger.info "Subscribing to data source #{config.platform} #{config.instrument} #{config.period}"
    client.emit 'subscribeDataSource', version, keys.cryptotrader.api_key,
      platform:config.platform
      instrument:config.instrument
      period:config.period
      limit:config.init_data_length + add_length
  client.on 'data_message', (msg)->
    logger.warn 'Server message: '+msg
  client.on 'data_error', (err)->
    logger.error err
  client.on 'data_init',(bars)->
    logger.verbose "Received historical market data #{bars.length} bar(s)"

    # Configuration of other options
    pl = config.platforms[config.platform]
    pl.fee = program.fee or pl.fee

    script = CoffeeScript.compile code,
       bare:true
    logger.info 'Starting backtest...'

    # Intialize a trader instance, no key, set backtest config
    config.platform = 'backtest'
    trader = new Trader name,config,null,script

    length_end = config.init_data_length + add_length - 1

    Fiber =>
       # Initialize the trader with the initial data
       trader.init(bars[0...add_length])


       # Gradually keep passing bars incrementally to trader
       for i in [add_length...length_end]
         bar = bars[i]
         trader.handle bar
         #TODO Add profit/loss calculation, and gains/losses quantitatively
         if i is length_end-1
            start_date = new Date(bars[add_length].at)
            end_date = new Date(bars[length_end].at)
            setTimeout (-> logger.info '\nSimulation started ' + start_date + '\nSimulation ended ' + end_date), 2000 
     .run()
