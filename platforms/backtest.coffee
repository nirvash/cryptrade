Platform = require '../platform'

class BacktestPlatform extends Platform
  init: (@config,@pair,@account)->
    @wallet = {}
    @orders = []

    @orderid  = 1

    pair = @pair.split('_')
    for x in pair
      @wallet[x.toLowerCase()] = @config.initial_portfolio[x.toLowerCase()] or 0.0

    @fee = @config.fee or 0.5

    @ticker =
      buy: 1.0
      sell: 1.0

  getPositions: (positions,cb)->
    result = {}
    for curr, value of @wallet
      curr = curr.toLowerCase()
      if curr in positions
        result[curr] = value
    cb(null,result)

  trade: (order, cb)->
    amount = order.maxAmount

    switch order.type
      when 'buy'
        @wallet[order.asset] += amount * (1 - @fee/100)
        @wallet[order.curr]  -= amount * @ticker.buy
        break
      when 'sell'
        @wallet[order.asset] -= amount
        @wallet[order.curr]  += amount * (1 - @fee/100) * @ticker.sell
        break

    cb null,@orderid++

  isOrderActive: (orderId, cb)->
    # TODO: Right now orders are always fulfilled, at whatever price you want to buy.
    #       Should only fulfill buy orders with buy price > high, and sell with price lower < low
    #       as an estimate of actual behavior.
    cb null,false

  getOrders: (cb)->
    cb(@orders)

  cancelOrder: (orderId,cb)->
    self = @
    if orderId in @orders
      @orders = (x for x in @orders if x != orderId)

    if cb?
      cb null

  setTicker: (buy, sell, cb) ->
    @ticker.buy = buy
    @ticker.sell = sell

    if cb?
      cb()

  getTicker: (cb)->
    cb null,
      buy: @ticker.buy
      sell: @ticker.sell

module.exports = BacktestPlatform
