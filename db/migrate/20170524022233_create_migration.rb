require "dotenv"

ActiveRecord::Base.establish_connection(ENV["postgresql-flexible-24081"] || "postgres://mwvfdbywwseysv:3a1e0ca5ba219e2bf4e8aa6d1290fb01c71f565f335fcbf8701524eb676ae5e3@ec2-184-73-236-170.compute-1.amazonaws.com:5432/d3suersi6s7tmn")

class CreateMigration < ActiveRecord::Migration[5.1]
  def change
  end
end

