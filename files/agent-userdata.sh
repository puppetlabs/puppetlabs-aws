#!/bin/bash

MASTER='ip-10-252-36-135.sa-east-1.compute.internal'

puppet config set server ${MASTER} --section agent
puppet config set certname $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --section agent

sed -i /etc/default/puppet -e 's/START=no/START=yes/'

puppet resource service puppet ensure=running enable=true
