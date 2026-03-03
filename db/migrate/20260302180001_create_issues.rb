class CreateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :issues do |t|
      t.string :name, null: false
      t.string :slug
      t.text :description
      t.string :stance_label
      t.string :against_label
      t.boolean :active, default: true, null: false
      t.integer :sort_order, default: 0, null: false
      t.string :icon

      t.timestamps
    end
    add_index :issues, :slug, unique: true
    add_index :issues, :active
    add_index :issues, :sort_order
  end
end
