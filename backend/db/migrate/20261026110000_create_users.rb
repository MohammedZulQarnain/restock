class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "read_only"
      t.boolean :active, null: false, default: true
      t.string :token_digest
      t.datetime :token_expires_at
      t.timestamps
    end
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
    add_index :users, :token_digest, unique: true
    add_check_constraint :users, "role IN ('admin', 'warehouse_operator', 'inspector', 'read_only')", name: "users_role_valid"
  end
end
