Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'minitest/autorun'
require 'yaml'
require 'byebug'
require 'json'
require 'socket'
require 'base64'
require 'net/http'
require 'dotenv/load'

require_relative 'request_helper'

require 'minitest/reporters'

