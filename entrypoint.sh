#!/bin/sh -l

echo "Hello $1"
time=$(date)
echo "::set-output name=time::$time"
ls

echo "::notice file=marketplace/analog_io_modules/pressure_sensor/manifest.yml,line=1,endLine=1,title=Спека::Это спека!"

echo "::error file=marketplace/analog_io_modules/pressure_sensor/firmware.lua,line=5,endLine=10,title=Test title::Test message"
