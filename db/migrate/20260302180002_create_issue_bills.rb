class CreateIssueBills < ActiveRecord::Migration[8.1]
  def change
    create_table :issue_bills do |t|
      t.references :issue, null: false, foreign_key: true
      t.references :bill, null: false, foreign_key: true
      t.integer :popular_position, default: 0, null: false
      t.integer :sort_order, default: 0, null: false

      t.timestamps
    end
    add_index :issue_bills, [:issue_id, :bill_id], unique: true
  end
end
