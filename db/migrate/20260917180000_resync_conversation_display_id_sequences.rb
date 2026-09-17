# frozen_string_literal: true

class ResyncConversationDisplayIdSequences < ActiveRecord::Migration[7.0]
  def up
    # In PostgreSQL, ensure conv_dpid_seq_<account_id> sequence is properly aligned with MAX(display_id)
    execute <<-SQL.squish
      DO $$
      DECLARE
        rec RECORD;
        max_id integer;
      BEGIN
        FOR rec IN SELECT id FROM accounts LOOP
          IF EXISTS (SELECT 1 FROM pg_sequences WHERE sequencename = 'conv_dpid_seq_' || rec.id) THEN
            SELECT COALESCE(MAX(display_id), 0) INTO max_id FROM conversations WHERE account_id = rec.id;
            EXECUTE format('SELECT setval(''conv_dpid_seq_%s'', %s, true)', rec.id, GREATEST(max_id, 1));
          END IF;
        END LOOP;
      END $$;
    SQL
  end

  def down
    # no-op
  end
end
