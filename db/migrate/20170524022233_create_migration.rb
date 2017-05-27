require "dotenv"

ActiveRecord::Base.establish_connection(ENV["postgresql-flexible-24081"] || "postgres://mwvfdbywwseysv:3a1e0ca5ba219e2bf4e8aa6d1290fb01c71f565f335fcbf8701524eb676ae5e3@ec2-184-73-236-170.compute-1.amazonaws.com:5432/d3suersi6s7tmn")

class CreateMigration < ActiveRecord::Migration[5.1]
  def change
    create_table :posts do |p|
      p.string :name
      p.text :body
      p.timestamps
      p.string :sent_to
      p.integer :kidoku
    end

    create_table :users do |user|
      user.string :name
      user.string :password_digest
      user.string :profile_url
    end

    create_table :friends do |friend|
      friend.string :user_name
      friend.string :frie_name
    end

    create_table :fadds do |fadd|
      fadd.string :req_from
      fadd.string :req_to
    end

  end
end

