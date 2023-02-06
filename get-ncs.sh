#!/bin/bash
echo "Hello World !"
pwd
mkdir ncs
cd ncs
west init -m https://github.com/nrfconnect/sdk-nrf
west update
