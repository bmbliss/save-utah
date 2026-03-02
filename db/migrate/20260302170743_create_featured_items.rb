class CreateFeaturedItems < ActiveRecord::Migration[8.1]
  def change
    create_table :featured_items do |t|
      t.references :featurable, polymorphic: true, null: false
      t.string :headline
      t.text :description
      t.integer :section
      t.integer :sort_order, default: 0
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
