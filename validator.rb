#! /usr/bin/env ruby
#
# Validates YAML files according to a schema (also in YAML).
#
# Author: Mike Bland (michael.bland@gsa.gov)
# Date:   2014-12-11
# Source: https://github.com/18F/data-validator

require_relative 'lib/validator'
require 'optparse'

options = {}

begin
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [schema file] [files to validate...]"

    opts.on_tail('-h', '--help', "Show this help") do
      puts opts
      exit
    end
  end
  opt_parser.parse!

  if ARGV.length < 1
    puts 'No schema and input file specified'
    exit 1
  elsif ARGV.length < 2
    puts 'Both a schema file and at least one input file are required'
    exit 1
  end
  schema_file = open(ARGV.shift, 'r')

rescue SystemExit
  raise

rescue Exception => e
  puts e
  exit 1
end

validator = Validator::Validator.new schema_file.read
