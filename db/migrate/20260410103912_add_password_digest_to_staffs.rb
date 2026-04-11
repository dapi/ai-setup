class AddPasswordDigestToStaffs < ActiveRecord::Migration[7.1]
  def change
    add_column :staffs, :password_digest, :string, null: false
  end
end
