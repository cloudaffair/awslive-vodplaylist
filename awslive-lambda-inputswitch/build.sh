#!/usr/bin/env bash
bundle install --path vendor/bundle
zip -r awslive-lambda-inputswitch.zip * vendor