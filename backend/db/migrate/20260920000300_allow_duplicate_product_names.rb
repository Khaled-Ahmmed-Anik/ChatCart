class AllowDuplicateProductNames < ActiveRecord::Migration[8.1]
  def change
    remove_index :products, column: [ :business_id, :name ]
  end
end
