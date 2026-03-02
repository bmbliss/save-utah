class CreateActionScripts < ActiveRecord::Migration[8.1]
  def change
    create_table :action_scripts do |t|
      t.string :title
      t.text :script_template
      t.text :context
      t.integer :action_type
      t.references :representative, null: true, foreign_key: true
      t.references :bill, null: true, foreign_key: true
      t.boolean :active, default: true, null: false
      t.boolean :featured, default: false, null: false
      t.integer :sort_order, default: 0

      t.timestamps
    end
  end
end
