#!/bin/sh

exec ruby /app/webserver/web.rb -p 80 -o 0.0.0.0
