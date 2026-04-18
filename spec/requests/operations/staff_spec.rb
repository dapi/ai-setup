# rubocop:disable Metrics/BlockLength
require "rails_helper"

RSpec.describe "Operations staff management" do
  let(:hotel) { create(:hotel) }
  let(:other_hotel) { create(:hotel) }
  let(:manager) { create(:staff, :manager, hotel: hotel) }
  let(:admin) { create(:staff, :admin, hotel: hotel) }
  let(:staff_user) { create(:staff, hotel: hotel) }
  let(:department) { create(:department, hotel: hotel, name: "Housekeeping") }
  let(:other_department) { create(:department, hotel: other_hotel, name: "Other Housekeeping") }

  describe "GET /operations/staff" do
    it "renders same-hotel staff for managers" do
      create(:staff, hotel: hotel, department: department, name: "Alice Staff", email: "alice@example.com")
      create(:staff, :manager, hotel: hotel, name: "Bob Manager")
      create(:staff, hotel: other_hotel, name: "Cross Hotel Staff")

      get operations_staff_index_path, headers: auth_header(manager)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice Staff", "alice@example.com", "Housekeeping")
      expect(response.body).not_to include("Bob Manager", "Cross Hotel Staff")
    end

    it "renders the empty state for managers" do
      get operations_staff_index_path, headers: auth_header(manager)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No staff found")
    end

    it "returns 403 for admins" do
      get operations_staff_index_path, headers: auth_header(admin)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for staff" do
      get operations_staff_index_path, headers: auth_header(staff_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /operations/staff/new" do
    it "renders only same-hotel departments for managers" do
      department
      other_department

      get new_operations_staff_path, headers: auth_header(manager)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Housekeeping")
      expect(response.body).not_to include("Other Housekeeping")
      expect(response.body).not_to include('name="staff[role]"', 'name="staff[hotel_id]"')
    end

    it "returns 403 for admins" do
      get new_operations_staff_path, headers: auth_header(admin)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for staff" do
      get new_operations_staff_path, headers: auth_header(staff_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /operations/staff" do
    it "creates staff with a same-hotel department" do
      expect do
        post operations_staff_index_path, headers: auth_header(manager), params: { staff: valid_params }
      end.to change(Staff.where(role: :staff, hotel: hotel), :count).by(1)

      created_staff = Staff.find_by!(email: "new.staff@example.com")
      expect(created_staff.department).to eq(department)
      expect(response).to redirect_to(operations_staff_index_path)
      expect(flash[:notice]).to eq("Staff created")
    end

    it "returns 422 for validation failures" do
      post operations_staff_index_path,
           headers: auth_header(manager),
           params: { staff: valid_params.merge(name: "", email: "") }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Name can&#39;t be blank", "Email can&#39;t be blank")
    end

    it "returns 422 for cross-hotel departments" do
      post operations_staff_index_path,
           headers: auth_header(manager),
           params: { staff: valid_params.merge(department_id: other_department.id) }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Department must belong to the same hotel")
    end

    it "returns 403 for admins" do
      post operations_staff_index_path, headers: auth_header(admin), params: { staff: valid_params }

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for staff" do
      post operations_staff_index_path, headers: auth_header(staff_user), params: { staff: valid_params }

      expect(response).to have_http_status(:forbidden)
    end

    it "does not allow params to set role or hotel" do
      post operations_staff_index_path,
           headers: auth_header(manager),
           params: { staff: valid_params.merge(role: :admin, hotel_id: other_hotel.id) }

      created_staff = Staff.find_by!(email: "new.staff@example.com")
      expect(created_staff).to be_staff
      expect(created_staff.hotel).to eq(hotel)
    end
  end

  def valid_params
    {
      name: "New Staff",
      email: "new.staff@example.com",
      password: "password",
      password_confirmation: "password",
      department_id: department.id
    }
  end
end
# rubocop:enable Metrics/BlockLength
