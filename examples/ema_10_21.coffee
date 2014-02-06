###
  EMA CROSSOVER TRADING ALGORITHM
  The script engine is based on CoffeeScript (http://coffeescript.org)
  Any trading algorithm needs to implement two methods: 
    init(context) and handle(context,data)
###        

class Functions
    @can_buy: (ins, min_btc, fee_percent) ->
        portfolio.positions[ins.curr()].amount >= ((ins.price * min_btc) * (1 + fee_percent / 100))
    @can_sell: (ins, min_btc) ->
        portfolio.positions[ins.asset()].amount >= min_btc

# Initialization method called before a simulation starts. 
# Context object holds script data and will be passed to 'handle' method. 
init: (context)->
    context.buy_treshold = 0.25
    context.sell_treshold = 0.25

# This method is called for each tick
handle: (context, data)->
    # data object provides access to the current candle bar
    instrument = data.instruments[0]
    short = instrument.ema(10) # calculate EMA value using ta-lib function
    long = instrument.ema(21)       
    diff = 100 * (short - long) / ((short + long) / 2)
    debug 'EMA difference: '+diff.toFixed(3)+' price: '+instrument.price.toFixed(2)+' at '+new Date(data.at)
    if diff > context.buy_treshold and Functions.can_buy(instrument, .01, .55)         
        buy instrument # Spend all amount of cash for BTC
    else
        if diff < -context.sell_treshold and Functions.can_sell(instrument, .01)
            sell instrument # Sell BTC position
   
