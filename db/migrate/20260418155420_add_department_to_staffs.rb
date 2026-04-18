class AddDepartmentToStaffs < ActiveRecord::Migration[7.1]
  CREATE_FALLBACK_DEPARTMENTS_SQL = <<~SQL.squish
    INSERT INTO departments (hotel_id, name, created_at, updated_at)
    SELECT DISTINCT staffs.hotel_id, 'General', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM staffs
    WHERE staffs.role = 2
      AND NOT EXISTS (
        SELECT 1
        FROM departments
        WHERE departments.hotel_id = staffs.hotel_id
      )
  SQL

  ASSIGN_STAFF_DEPARTMENTS_SQL = <<~SQL.squish
    UPDATE staffs
    SET department_id = first_departments.id,
        updated_at = CURRENT_TIMESTAMP
    FROM (
      SELECT DISTINCT ON (hotel_id) id, hotel_id
      FROM departments
      ORDER BY hotel_id, id
    ) first_departments
    WHERE staffs.role = 2
      AND staffs.department_id IS NULL
      AND first_departments.hotel_id = staffs.hotel_id
  SQL

  def up
    add_reference :staffs, :department, null: true, foreign_key: true
    add_index :staffs, :email, unique: true

    backfill_staff_departments

    add_check_constraint :staffs,
                         "role != 2 OR department_id IS NOT NULL",
                         name: "staff_role_requires_department"
  end

  def down
    remove_check_constraint :staffs, name: "staff_role_requires_department"
    remove_index :staffs, :email
    remove_reference :staffs, :department, foreign_key: true
  end

  private

  def backfill_staff_departments
    create_fallback_departments
    assign_staff_departments
  end

  def create_fallback_departments
    execute CREATE_FALLBACK_DEPARTMENTS_SQL
  end

  def assign_staff_departments
    execute ASSIGN_STAFF_DEPARTMENTS_SQL
  end
end
