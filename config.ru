require "rubygems"
require "bundler"
Bundler.require

require_relative "./app"

use ActiveRecord::ConnectionAdapters::ConnectionManagement

run MineApp