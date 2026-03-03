class AddHeroFieldsToIssues < ActiveRecord::Migration[8.1]
  def change
    add_column :issues, :hero_headline, :string
    add_column :issues, :hero_subheadline, :text
    add_column :issues, :hero_cta, :string
    add_column :issues, :hero_stat_1, :string
    add_column :issues, :hero_stat_2, :string
    add_column :issues, :og_title, :string
    add_column :issues, :og_description, :text
  end
end
