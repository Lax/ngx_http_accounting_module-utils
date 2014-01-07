#!/usr/bin/env ruby -w
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require './common.rb'
require './lib/graph.rb'

require './app.rb'

run AppController
