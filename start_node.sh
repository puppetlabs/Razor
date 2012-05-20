#!/bin/bash

# Starts node server or restarts if running

killall -2 node
nohup node ./bin/api.js &
nohup node ./bin/image_svc.js &
