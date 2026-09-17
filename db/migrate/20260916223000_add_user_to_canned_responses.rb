class AddUserToCannedResponses < ActiveRecord::Migration[7.2]
  def change
    add_reference :canned_responses, :user, foreign_key: true, index: true, null: true

    reversible do |dir|
      dir.up do
        # Backfill existing canned responses with the first administrator of the account if available
        execute <<-SQL.squish
          UPDATE canned_responses cr
          SET user_id = (
            SELECT au.user_id
            FROM account_users au
            WHERE au.account_id = cr.account_id AND au.role = 1
            ORDER BY au.id ASC
            LIMIT 1
          )
          WHERE cr.user_id IS NULL;
        SQL
      end
    end
  end
end
