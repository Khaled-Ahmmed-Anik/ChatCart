class AddRevocationToAuthSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :auth_sessions, :revoked_at, :datetime
    add_column :auth_sessions, :revocation_reason, :string
    add_index :auth_sessions, :revoked_at
  end
end
