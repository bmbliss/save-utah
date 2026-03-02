class CreateBills < ActiveRecord::Migration[8.1]
  def change
    create_table :bills do |t|
      t.string :title
      t.string :slug
      t.string :bill_number
      t.text :summary
      t.text :editorial_summary
      t.string :full_text_url
      t.string :status
      t.integer :level
      t.string :chamber
      t.integer :session_year
      t.string :session_name
      t.boolean :featured, default: false, null: false
      t.date :introduced_on
      t.date :last_action_on
      t.string :congress_bill_id
      t.string :utah_bill_id
      t.string :openstates_bill_id
      t.string :data_source

      t.timestamps
    end
    add_index :bills, :slug, unique: true
    add_index :bills, :level
    add_index :bills, :session_year
    add_index :bills, :featured
    add_index :bills, :status
    add_index :bills, :congress_bill_id, unique: true, where: "congress_bill_id IS NOT NULL"
    add_index :bills, :utah_bill_id, unique: true, where: "utah_bill_id IS NOT NULL"
  end
end
