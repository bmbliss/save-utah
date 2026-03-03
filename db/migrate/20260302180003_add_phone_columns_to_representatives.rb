class AddPhoneColumnsToRepresentatives < ActiveRecord::Migration[8.1]
  def change
    add_column :representatives, :phone_mobile, :string
    add_column :representatives, :phone_work, :string
    add_column :representatives, :phone_home, :string
  end
end
