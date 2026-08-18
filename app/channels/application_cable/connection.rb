module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = authenticated_user || reject_unauthorized_connection
    end

    private

    def authenticated_user
      payload = decoded_access_token
      payload && User.find_by(id: payload["user_id"])
    end

    # Same "type" == "access" restriction as ApplicationController#decoded_access_token
    # — a refresh token must not be usable to open a socket. Browsers can't set an
    # Authorization header on a WebSocket upgrade, so the token travels as a query
    # param instead: wss://host/cable?token=<access_token>.
    def decoded_access_token
      payload = JsonWebToken.decode(request.params[:token])
      payload && payload["type"] == "access" ? payload : nil
    end
  end
end
