class AddHideEmptyFieldsToItemTypes < ActiveRecord::Migration
  def up
    add_column :item_types, :display_emtpy_fields, :boolean, :null => false, default: true
  end

  def down
    remove_column :item_types, :display_emtpy_fields
  end
end
