class CreateRepresentatives < ActiveRecord::Migration[8.1]
  def change
    create_table :representatives do |t|
      t.string :first_name
      t.string :last_name
      t.string :full_name
      t.string :slug
      t.string :title
      t.integer :position_type
      t.integer :level
      t.string :chamber
      t.string :party
      t.string :district
      t.string :photo_url
      t.string :phone
      t.string :email
      t.text :office_address
      t.string :website_url
      t.string :twitter_handle
      t.string :facebook_url
      t.boolean :active, default: true, null: false
      t.string :bioguide_id
      t.string :utah_leg_id
      t.string :openstates_id

      t.timestamps
    end
    add_index :representatives, :slug, unique: true
    add_index :representatives, :position_type
    add_index :representatives, :level
    add_index :representatives, :party
    add_index :representatives, :active
    add_index :representatives, :bioguide_id, unique: true, where: "bioguide_id IS NOT NULL"
    add_index :representatives, :utah_leg_id, unique: true, where: "utah_leg_id IS NOT NULL"
    add_index :representatives, :openstates_id, unique: true, where: "openstates_id IS NOT NULL"
  end
end
