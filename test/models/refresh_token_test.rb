require "test_helper"

class RefreshTokenTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "alice", email: "alice@example.com", password: "password123")
  end

  test "jti and expires_at are required" do
    token = RefreshToken.new(user: @user)
    assert_not token.valid?
    assert_includes token.errors[:jti], "can't be blank"
    assert_includes token.errors[:expires_at], "can't be blank"
  end

  test "jti must be unique" do
    RefreshToken.create!(user: @user, jti: "dup-jti", expires_at: 7.days.from_now)

    dup = RefreshToken.new(user: @user, jti: "dup-jti", expires_at: 7.days.from_now)
    assert_not dup.valid?
    assert_includes dup.errors[:jti], "has already been taken"
  end

  test "revoked? reflects revoked_at" do
    token = RefreshToken.create!(user: @user, jti: SecureRandom.uuid, expires_at: 7.days.from_now)
    assert_not token.revoked?

    token.update!(revoked_at: Time.current)
    assert token.revoked?
  end

  test "destroying a user destroys their refresh tokens" do
    token = RefreshToken.create!(user: @user, jti: SecureRandom.uuid, expires_at: 7.days.from_now)

    @user.destroy!

    assert_nil RefreshToken.find_by(id: token.id)
  end
end
