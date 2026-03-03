class AddStateToRepresentatives < ActiveRecord::Migration[8.1]
  def change
    add_column :representatives, :state, :string

    # Backfill: any rep with a utah_leg_id or openstates_id is from Utah.
    # State-level reps are always Utah (this is a Utah-only app).
    # Federal reps imported via Congress.gov /member/UT are also Utah,
    # but non-Utah federal reps may exist from vote imports — leave those nil.
    reversible do |dir|
      dir.up do
        # All state-level reps → "UT"
        execute "UPDATE representatives SET state = 'UT' WHERE level = 1"
        # All executives → "UT"
        execute "UPDATE representatives SET state = 'UT' WHERE position_type IN (4, 5, 6, 7, 8)"
      end
    end

    add_index :representatives, :state
  end
end
