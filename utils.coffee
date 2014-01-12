https = require 'https'
inspect = require('util').inspect

module.exports =
  inspect: (obj)->
    result = inspect obj,
      colors:true
    result.replace '\n',' '
  downloadURL: (url,cb)->
    req = https.request url, (res)->
      res.on 'data', (data) ->
        cb(null,data)
    req.end()
    req.on 'error', (e)->
      cb(e)

  printDate: (date) ->
    padStr = (x) ->
      if (x < 10)
        x = "0" + x
      else
        x = "" + x
      x

    dateStr = padStr(date.getFullYear()) + "-" +
              padStr(1 + date.getMonth()) + "-" +
              padStr(date.getDate()) + " " +
              padStr(date.getHours()) + ":" +
              padStr(date.getMinutes())

