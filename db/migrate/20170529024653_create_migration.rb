class CreateMigration < ActiveRecord::Migration[5.1]
    def change
      create_table :posts do |p|
        p.belongs_to :talkroom
        p.belongs_to :user
        p.text :body
        p.integer :kidoku
        p.timestamps
      end

      create_table :users do |user|
        user.string :name
        user.string :password_digest
        user.string :profile_url
        user.timestamps
      end

      create_table :relationships do |rel|
        rel.belongs_to :user
        rel.integer :friend_id
        rel.string :status
        rel.timestamps
      end

      create_table :talkrooms do |tr|
        tr.string :name
        tr.timestamps
      end
    end
end
