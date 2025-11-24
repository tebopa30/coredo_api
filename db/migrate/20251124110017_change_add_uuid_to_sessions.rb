class ChangeAddUuidToSessions < ActiveRecord::Migration[8.1]
  def up
    # 既存のNULLを埋める
    Session.where(uuid: nil).find_each do |s|
      s.update_columns(uuid: SecureRandom.uuid)
    end

    # 既存インデックスを削除してユニークインデックスを追加
    remove_index :sessions, :uuid rescue nil
    add_index :sessions, :uuid, unique: true

    # NOT NULL 制約を追加
    change_column_null :sessions, :uuid, false
  end

  def down
    remove_index :sessions, :uuid
    add_index :sessions, :uuid
    change_column_null :sessions, :uuid, true
  end
end
