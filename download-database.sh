#!/bin/bash

SITE=$1
cd /home/variant-server
if [ -n "$SITE" ]; then
    curl -L $SITE | pbzip2 -dc - | tar -xvf -
fi
