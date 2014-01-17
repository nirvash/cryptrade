#! /bin/bash

while :
do
    node_modules/.bin/iced backtrade.coffee "$@"
    sleep 15
done
