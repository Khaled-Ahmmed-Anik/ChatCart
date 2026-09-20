class AddPasswordAuthentication < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_digest, :string

    create_table :platform_administrators do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :platform_administrators, :email, unique: true

    create_table :auth_sessions do |t|
      t.references :user, foreign_key: true
      t.references :platform_administrator, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
    add_index :auth_sessions, :token_digest, unique: true
    add_index :auth_sessions, :expires_at
    add_check_constraint :auth_sessions,
      "(user_id IS NOT NULL AND platform_administrator_id IS NULL) OR (user_id IS NULL AND platform_administrator_id IS NOT NULL)",
      name: "auth_sessions_exactly_one_actor"
  end
end
