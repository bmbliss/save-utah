class AddHotToIssues < ActiveRecord::Migration[8.1]
  def change
    add_column :issues, :hot, :boolean, default: false, null: false
  end
end
