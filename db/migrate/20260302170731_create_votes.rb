class CreateVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :votes do |t|
      t.references :representative, null: false, foreign_key: true
      t.references :bill, null: false, foreign_key: true
      t.integer :position
      t.date :voted_on
      t.string :data_source

      t.timestamps
    end
    add_index :votes, [:representative_id, :bill_id], unique: true
  end
end
