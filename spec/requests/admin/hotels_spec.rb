require "rails_helper"

RSpec.describe "Admin hotels" do
  describe "GET /admin/hotels" do
    let!(:hotel) { create(:hotel, name: "Grand Palace") }

    describe "authentication" do
      it "returns 401 with WWW-Authenticate when no Authorization header" do
        get admin_hotels_path

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Admin"')
      end

      it "returns 401 with WWW-Authenticate for Bearer token" do
        get admin_hotels_path, headers: { "Authorization" => "Bearer sometoken" }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Admin"')
      end

      it "returns 401 with WWW-Authenticate for invalid base64" do
        get admin_hotels_path, headers: { "Authorization" => "Basic !!!" }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Admin"')
      end

      it "returns 401 when email not found in DB" do
        encoded = Base64.strict_encode64("unknown@example.com:password")
        get admin_hotels_path, headers: { "Authorization" => "Basic #{encoded}" }

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when password is wrong" do
        staff = create(:staff, :admin, hotel: hotel)
        encoded = Base64.strict_encode64("#{staff.email}:wrongpassword")
        get admin_hotels_path, headers: { "Authorization" => "Basic #{encoded}" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "authorization" do
      it "returns 200 with hotel name for admin role" do
        admin = create(:staff, :admin, hotel: hotel)
        get admin_hotels_path, headers: auth_header(admin)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(hotel.name)
      end

      it "returns 302 redirect to root_path for manager role" do
        manager = create(:staff, :manager, hotel: hotel)
        get admin_hotels_path, headers: auth_header(manager)

        expect(response).to redirect_to(root_path)
      end

      it "returns 302 redirect to root_path for staff role" do
        staff = create(:staff, hotel: hotel)
        get admin_hotels_path, headers: auth_header(staff)

        expect(response).to redirect_to(root_path)
      end
    end

    describe "content" do
      it "renders the hotels table when hotels exist" do
        admin = create(:staff, :admin, hotel: hotel)

        get admin_hotels_path, headers: auth_header(admin)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Hotels", hotel.name, hotel.timezone)
      end

      it "renders the empty state when no hotels exist" do
        admin = create(:staff, :admin, hotel: hotel)
        allow(Hotel).to receive(:order).with(:name).and_return(Hotel.none)

        get admin_hotels_path, headers: auth_header(admin)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No hotels yet.")
      end
    end
  end

  describe "GET /admin/hotels/:slug" do
    let!(:hotel) { create(:hotel, name: "Grand Palace", slug: "grand-palace-slug", timezone: "Europe/Moscow") }

    it "returns 401 when not authenticated" do
      get admin_hotel_path(hotel)

      expect(response).to have_http_status(:unauthorized)
    end

    it "renders the hotel details for admin role" do
      admin = create(:staff, :admin, hotel: hotel)

      get admin_hotel_path(hotel), headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(hotel.name, hotel.timezone, hotel.slug)
      expect(response.body).to include(admin_hotel_staff_index_path(hotel), admin_hotel_tickets_path(hotel))
    end

    it "redirects manager to root" do
      manager = create(:staff, :manager, hotel: hotel)

      get admin_hotel_path(hotel), headers: auth_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      staff = create(:staff, hotel: hotel)

      get admin_hotel_path(hotel), headers: auth_header(staff)

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when the hotel is not found" do
      admin = create(:staff, :admin, hotel: hotel)

      get admin_hotel_path("missing-slug"), headers: auth_header(admin)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq("Not Found")
    end
  end

  describe "GET /admin/hotels/new" do
    let!(:hotel) { create(:hotel) }

    it "returns 401 when not authenticated" do
      get new_admin_hotel_path

      expect(response).to have_http_status(:unauthorized)
    end

    it "renders the form for admin role" do
      admin = create(:staff, :admin, hotel: hotel)

      get new_admin_hotel_path, headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New Hotel", "Create Hotel")
    end

    it "redirects manager to root" do
      manager = create(:staff, :manager, hotel: hotel)

      get new_admin_hotel_path, headers: auth_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      staff = create(:staff, hotel: hotel)

      get new_admin_hotel_path, headers: auth_header(staff)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /admin/hotels" do
    let!(:hotel) { create(:hotel) }

    it "returns 401 when not authenticated" do
      post admin_hotels_path, params: { hotel: { name: "Aurora", timezone: "Europe/London" } }

      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a hotel for admin role" do
      admin = create(:staff, :admin, hotel: hotel)

      expect do
        post admin_hotels_path,
             params: { hotel: { name: "Aurora Palace", timezone: "Europe/London", slug: "ignored-slug" } },
             headers: auth_header(admin)
      end.to change(Hotel, :count).by(1)

      created_hotel = Hotel.order(:created_at).last

      expect(response).to redirect_to(admin_hotels_path)
      expect(flash[:notice]).to eq("Hotel was successfully created.")
      expect(created_hotel.slug).to eq("aurora-palace-slug")
    end

    it "renders errors when the hotel is invalid" do
      admin = create(:staff, :admin, hotel: hotel)

      expect do
        post admin_hotels_path,
             params: { hotel: { name: "", timezone: "" } },
             headers: auth_header(admin)
      end.not_to change(Hotel, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Name can&#39;t be blank", "Timezone can&#39;t be blank")
    end

    it "renders errors when the hotel name is missing" do
      admin = create(:staff, :admin, hotel: hotel)

      expect do
        post admin_hotels_path,
             params: { hotel: { name: "", timezone: "Europe/London" } },
             headers: auth_header(admin)
      end.not_to change(Hotel, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Name can&#39;t be blank")
    end

    it "renders errors when the hotel timezone is missing" do
      admin = create(:staff, :admin, hotel: hotel)

      expect do
        post admin_hotels_path,
             params: { hotel: { name: "Aurora Palace", timezone: "" } },
             headers: auth_header(admin)
      end.not_to change(Hotel, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Timezone can&#39;t be blank")
    end

    it "renders errors when name and generated slug are duplicates" do
      admin = create(:staff, :admin, hotel: hotel)
      existing_hotel = create(:hotel, name: "Duplicate Hotel", slug: "duplicate-hotel-slug")

      expect do
        post admin_hotels_path,
             params: { hotel: { name: existing_hotel.name, timezone: "Europe/London" } },
             headers: auth_header(admin)
      end.not_to change(Hotel, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Name has already been taken", "Slug has already been taken")
    end

    it "redirects manager to root" do
      manager = create(:staff, :manager, hotel: hotel)

      post admin_hotels_path,
           params: { hotel: { name: "Aurora Palace", timezone: "Europe/London" } },
           headers: auth_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      staff = create(:staff, hotel: hotel)

      post admin_hotels_path,
           params: { hotel: { name: "Aurora Palace", timezone: "Europe/London" } },
           headers: auth_header(staff)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /admin/hotels/:slug/edit" do
    let!(:hotel) { create(:hotel, name: "Grand Palace", slug: "grand-palace-slug", timezone: "Europe/Moscow") }

    it "returns 401 when not authenticated" do
      get edit_admin_hotel_path(hotel)

      expect(response).to have_http_status(:unauthorized)
    end

    it "renders the edit form for admin role" do
      admin = create(:staff, :admin, hotel: hotel)

      get edit_admin_hotel_path(hotel), headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit Hotel", "Update Hotel", hotel.name)
    end

    it "redirects manager to root" do
      manager = create(:staff, :manager, hotel: hotel)

      get edit_admin_hotel_path(hotel), headers: auth_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      staff = create(:staff, hotel: hotel)

      get edit_admin_hotel_path(hotel), headers: auth_header(staff)

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when the hotel is not found" do
      admin = create(:staff, :admin, hotel: hotel)

      get edit_admin_hotel_path("missing-slug"), headers: auth_header(admin)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq("Not Found")
    end
  end

  describe "PATCH /admin/hotels/:slug" do
    let!(:hotel) { create(:hotel, name: "Grand Palace", slug: "grand-palace-slug", timezone: "Europe/Moscow") }

    it "returns 401 when not authenticated" do
      patch admin_hotel_path(hotel), params: { hotel: { name: "Aurora", timezone: "Europe/London" } }

      expect(response).to have_http_status(:unauthorized)
    end

    it "updates a hotel for admin role" do
      admin = create(:staff, :admin, hotel: hotel)

      patch admin_hotel_path(hotel),
            params: { hotel: { name: "Aurora", timezone: "Europe/London", slug: "ignored-slug" } },
            headers: auth_header(admin)

      expect(response).to redirect_to(admin_hotels_path)
      expect(flash[:notice]).to eq("Hotel was successfully updated.")
      expect(hotel.reload.name).to eq("Aurora")
      expect(hotel.timezone).to eq("Europe/London")
      expect(hotel.slug).to eq("grand-palace-slug")
    end

    it "renders errors when the hotel is invalid" do
      admin = create(:staff, :admin, hotel: hotel)

      patch admin_hotel_path(hotel),
            params: { hotel: { name: "", timezone: "" } },
            headers: auth_header(admin)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Name can&#39;t be blank", "Timezone can&#39;t be blank")
      expect(hotel.reload.slug).to eq("grand-palace-slug")
    end

    it "redirects manager to root" do
      manager = create(:staff, :manager, hotel: hotel)

      patch admin_hotel_path(hotel),
            params: { hotel: { name: "Aurora", timezone: "Europe/London" } },
            headers: auth_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      staff = create(:staff, hotel: hotel)

      patch admin_hotel_path(hotel),
            params: { hotel: { name: "Aurora", timezone: "Europe/London" } },
            headers: auth_header(staff)

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when the hotel is not found" do
      admin = create(:staff, :admin, hotel: hotel)

      patch admin_hotel_path("missing-slug"),
            params: { hotel: { name: "Aurora", timezone: "Europe/London" } },
            headers: auth_header(admin)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq("Not Found")
    end
  end

  describe "DELETE /admin/hotels/:slug" do
    let!(:admin_hotel) { create(:hotel, name: "Admin Hotel", slug: "admin-hotel-slug") }
    let!(:admin) { create(:staff, :admin, hotel: admin_hotel) }

    it "returns 401 when not authenticated" do
      hotel = create(:hotel, name: "Grand Palace", slug: "grand-palace-slug")

      delete admin_hotel_path(hotel)

      expect(response).to have_http_status(:unauthorized)
    end

    it "deletes a hotel for admin role" do
      hotel = create(:hotel, name: "Grand Palace", slug: "grand-palace-slug")

      expect do
        delete admin_hotel_path(hotel), headers: auth_header(admin)
      end.to change(Hotel, :count).by(-1)

      expect(response).to redirect_to(admin_hotels_path)
      expect(flash[:notice]).to eq("Hotel was successfully deleted.")
    end

    it "does not delete a hotel with associated records" do
      hotel = create(:hotel, name: "Grand Palace", slug: "grand-palace-slug")
      guest = create(:guest, hotel: hotel)
      department = create(:department, hotel: hotel)
      create(:ticket, hotel: hotel, guest: guest, department: department, staff: nil)

      expect do
        delete admin_hotel_path(hotel), headers: auth_header(admin)
      end.not_to change(Hotel, :count)

      expect(response).to redirect_to(admin_hotels_path)
      expect(flash[:alert]).to eq("Hotel has associated records and cannot be deleted.")
    end

    it "redirects manager to root" do
      hotel = create(:hotel, name: "Grand Palace", slug: "grand-palace-slug")
      manager = create(:staff, :manager, hotel: admin_hotel)

      delete admin_hotel_path(hotel), headers: auth_header(manager)

      expect(response).to redirect_to(root_path)
    end

    it "redirects staff to root" do
      hotel = create(:hotel, name: "Grand Palace", slug: "grand-palace-slug")
      staff = create(:staff, hotel: admin_hotel)

      delete admin_hotel_path(hotel), headers: auth_header(staff)

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when the hotel is not found" do
      expect do
        delete admin_hotel_path("missing-slug"), headers: auth_header(admin)
      end.not_to change(Hotel, :count)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq("Not Found")
    end
  end
end
