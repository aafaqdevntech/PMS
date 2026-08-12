require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(username: "admin", email: "admin@example.com", password: "password123")
    EmploymentDetail.create!(user: @admin, role: :admin, job_position: "Admin", joined_at: Time.current)

    @owner = User.create!(username: "owner", email: "owner@example.com", password: "password123")
    Profile.create!(user: @owner, full_name: "Owner Person")

    # no profile for @other
    @other = User.create!(username: "other", email: "other@example.com", password: "password123")

    @outsider = User.create!(username: "outsider", email: "outsider@example.com", password: "password123")

    @admin_token = login(@admin)
    @owner_token = login(@owner)
    @outsider_token = login(@outsider)
  end

  # --- show ---

  test "the owner can view their own profile" do
    get "/users/#{@owner.id}/profile", headers: auth_headers(@owner_token)
    assert_response :ok
    assert_equal "Owner Person", JSON.parse(response.body)["full_name"]
  end

  test "an admin can view anyone's profile" do
    get "/users/#{@owner.id}/profile", headers: auth_headers(@admin_token)
    assert_response :ok
  end

  test "a non-owner, non-admin cannot view someone else's profile" do
    get "/users/#{@owner.id}/profile", headers: auth_headers(@outsider_token)
    assert_response :forbidden
  end

  test "viewing a profile that was never created is a 404 for the owner" do
    get "/users/#{@other.id}/profile", headers: auth_headers(login(@other))
    assert_response :not_found
  end

  test "a missing profile 404s even for a non-owner, before the forbidden check runs" do
    get "/users/#{@other.id}/profile", headers: auth_headers(@outsider_token)
    assert_response :not_found
  end

  # --- create ---

  test "an admin can create a profile for a user" do
    post "/users/#{@other.id}/profile", params: { full_name: "Other Person", city: "Metropolis" },
      headers: auth_headers(@admin_token)
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Other Person", body["full_name"]
    assert_equal "Metropolis", body["city"]
  end

  test "a non-admin cannot create a profile, even their own" do
    post "/users/#{@other.id}/profile", params: { full_name: "Other Person" }, headers: auth_headers(login(@other))
    assert_response :forbidden
  end

  test "full_name is required to create a profile" do
    post "/users/#{@other.id}/profile", params: { full_name: "" }, headers: auth_headers(@admin_token)
    assert_response :unprocessable_entity
  end

  test "a user cannot have two profiles; the existing one is left untouched" do
    post "/users/#{@owner.id}/profile", params: { full_name: "Duplicate" }, headers: auth_headers(@admin_token)

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "Use PATCH"

    assert_equal "Owner Person", @owner.reload.profile.full_name
  end

  # --- update ---

  test "an admin can update a profile" do
    patch "/users/#{@owner.id}/profile", params: { city: "Gotham" }, headers: auth_headers(@admin_token)
    assert_response :ok
    assert_equal "Gotham", JSON.parse(response.body)["city"]
  end

  test "the owner cannot update their own profile" do
    patch "/users/#{@owner.id}/profile", params: { city: "Gotham" }, headers: auth_headers(@owner_token)
    assert_response :forbidden
  end

  test "updating a profile that does not exist is a 404" do
    patch "/users/#{@other.id}/profile", params: { city: "Gotham" }, headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  # --- destroy ---

  test "an admin can delete a profile" do
    delete "/users/#{@owner.id}/profile", headers: auth_headers(@admin_token)
    assert_response :no_content
    assert_nil Profile.find_by(user_id: @owner.id)
  end

  test "the owner cannot delete their own profile" do
    delete "/users/#{@owner.id}/profile", headers: auth_headers(@owner_token)
    assert_response :forbidden
  end

  test "deleting a profile that does not exist is a 404" do
    delete "/users/#{@other.id}/profile", headers: auth_headers(@admin_token)
    assert_response :not_found
  end

  private

  def login(user)
    post "/auth/login", params: { login: user.username, password: "password123" }
    JSON.parse(response.body)["access_token"]
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
