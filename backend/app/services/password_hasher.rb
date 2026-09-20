require "openssl"
require "base64"

class PasswordHasher
  ITERATIONS = 310_000
  KEY_LENGTH = 32
  DIGEST = "SHA256"

  def self.create(password)
    raise ArgumentError, "Password must be at least 12 characters" if password.to_s.length < 12

    salt = SecureRandom.random_bytes(16)
    hash = OpenSSL::KDF.pbkdf2_hmac(password, salt: salt, iterations: ITERATIONS, length: KEY_LENGTH, hash: DIGEST)
    [ "pbkdf2_sha256", ITERATIONS, Base64.strict_encode64(salt), Base64.strict_encode64(hash) ].join("$")
  end

  def self.matches?(digest, password)
    algorithm, iterations, encoded_salt, encoded_hash = digest.to_s.split("$", 4)
    return false unless algorithm == "pbkdf2_sha256" && iterations.present? && encoded_salt.present? && encoded_hash.present?

    expected = Base64.strict_decode64(encoded_hash)
    actual = OpenSSL::KDF.pbkdf2_hmac(
      password.to_s,
      salt: Base64.strict_decode64(encoded_salt),
      iterations: iterations.to_i,
      length: expected.bytesize,
      hash: DIGEST
    )
    ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  rescue ArgumentError
    false
  end
end
