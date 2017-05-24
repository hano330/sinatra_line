require "rubygems"
require "bundler"
Bundler.require

require_relative "./app"

use ActiveRecord::ConnectionAdapters

run MineApp