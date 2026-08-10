class CreateRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :refresh_tokens do |t|
      t.references :user, null: false, foreign_key: true, index: true
      # The refresh JWT's own jti claim — this is what /auth/logout and
      # /auth/refresh look up to check revocation. The token itself still
      # carries its own exp; expires_at here is bookkeeping, not a second
      # expiry gate.
      t.string :jti, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :refresh_tokens, :jti, unique: true
  end
end
