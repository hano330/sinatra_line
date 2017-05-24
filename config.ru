require "rubygems"
require "bundler"
Bundler.require

require_relative "./app"

use ActiveRecord::ConnectionAdapters::PostgreSQL

run MineApp