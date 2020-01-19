#!/usr/bin/env bash
bundle install --path vendor/bundle
zip -r awslive-lambda-channelmonitor.zip * vendor deps