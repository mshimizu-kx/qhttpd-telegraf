#!/bin/bash
docker run --net=host -v $PWD/telegraf.conf:/etc/telegraf/telegraf.conf:ro telegraf
