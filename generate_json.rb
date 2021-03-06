#! /usr/bin/env ruby

require 'date'
require 'json'
require 'fileutils'
require 'jbuilder'
require_relative 'lib/helper'
require_relative 'lib/plan_year'
require_relative 'lib/date'
require_relative 'lib/broker_util'
require_relative 'lib/scenarios'

branch = ARGV[0] || 'master'
$github_url_prefix = "https://raw.githubusercontent.com/dchealthlink/HBX-mobile-app-API/blob/#{branch}"

$GENERATED_DIR = 'generated'
$ROOT_DIRECTORY = "#{__dir__}/#{$GENERATED_DIR}"
$BROKER_FILE_NAME = 'broker_details.json'

Scenarios.create_accounts
Scenarios.create_broker_1
Scenarios.create_empty_broker
Scenarios.create_broker_er_in_open_enrollment
Scenarios.create_broker_er_in_pending