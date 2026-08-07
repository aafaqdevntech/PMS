class JsonWebToken
  ALGORITHM = "HS256".freeze

  def self.secret
    Rails.application.secret_key_base
  end

  def self.encode(payload, expires_at)
    payload = payload.dup
    payload[:exp] = expires_at.to_i
    JWT.encode(payload, secret, ALGORITHM)
  end

  def self.decode(token)
    return nil if token.blank? || !token.is_a?(String)

    decoded = JWT.decode(token, secret, true, algorithm: ALGORITHM)[0]
    ActiveSupport::HashWithIndifferentAccess.new(decoded)
  rescue JWT::DecodeError, JWT::ExpiredSignature, ArgumentError
    nil
  end
end
