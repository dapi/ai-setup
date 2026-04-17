class AddSubjectAndBodyToTickets < ActiveRecord::Migration[7.1]
  def change
    add_column :tickets, :subject, :string, null: false, default: ""
    add_column :tickets, :body, :text, null: false, default: ""
  end
end
