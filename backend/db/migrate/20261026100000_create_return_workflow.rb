class CreateReturnWorkflow < ActiveRecord::Migration[7.1]
  def change
    create_table :returns do |t|
      t.string :return_number, null: false
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.string :order_reference
      t.string :reason, null: false
      t.text :customer_notes
      t.string :status, null: false, default: "registered"
      t.datetime :received_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :returns, :return_number, unique: true
    add_index :returns, :status
    add_index :returns, :created_at

    create_table :inspections do |t|
      t.references :return, null: false, foreign_key: true
      t.string :condition, null: false
      t.string :functional_status, null: false
      t.boolean :accessories_complete, null: false, default: false
      t.boolean :issue_found, null: false, default: false
      t.text :damage_notes
      t.text :notes
      t.datetime :inspected_at
      t.timestamps
    end
    add_index :inspections, :created_at

    create_table :dispositions do |t|
      t.references :return, null: false, foreign_key: true
      t.references :inspection, null: false, foreign_key: true
      t.string :disposition_type, null: false
      t.string :reason, null: false
      t.text :notes
      t.datetime :decided_at, null: false
      t.timestamps
    end
    add_index :dispositions, :return_id, unique: true

    create_table :inventories do |t|
      t.references :product, null: false, foreign_key: true
      t.string :bucket, null: false
      t.integer :quantity, null: false, default: 0
      t.timestamps
    end
    add_index :inventories, %i[product_id bucket], unique: true

    create_table :inventory_movements do |t|
      t.references :product, null: false, foreign_key: true
      t.references :inventory, null: false, foreign_key: true
      t.references :return, foreign_key: true
      t.string :movement_type, null: false
      t.integer :quantity_delta, null: false
      t.string :reason, null: false
      t.string :idempotency_key, null: false
      t.timestamps
    end
    add_index :inventory_movements, :idempotency_key, unique: true
    add_index :inventory_movements, :created_at

    create_table :audit_events do |t|
      t.references :return, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
    add_index :audit_events, :event_type
    add_index :audit_events, :created_at
  end
end
