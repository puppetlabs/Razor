#!/bin/bash
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#

# Starts node server or restarts if running

killall -2 node
nohup node ./bin/api.js &
nohup node ./bin/image_svc.js &
