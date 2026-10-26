require "digest"
require "securerandom"

class User < ApplicationRecord
  has_secure_password

  ROLES = %w[admin warehouse_operator inspector read_only].freeze
  TOKEN_TTL = 12.hours

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: ROLES }

  def issue_api_token!
    raw_token = SecureRandom.urlsafe_base64(32)
    update!(token_digest: Digest::SHA256.hexdigest(raw_token), token_expires_at: TOKEN_TTL.from_now)
    raw_token
  end

  def revoke_api_token!
    update!(token_digest: nil, token_expires_at: nil)
  end

  def self.from_api_token(raw_token)
    return if raw_token.blank?

    digest = Digest::SHA256.hexdigest(raw_token)
    user = find_by(token_digest: digest, active: true)
    return unless user&.token_expires_at&.future?

    user
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
