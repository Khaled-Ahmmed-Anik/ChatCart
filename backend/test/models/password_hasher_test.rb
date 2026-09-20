require "test_helper"

class PasswordHasherTest < ActiveSupport::TestCase
  test "stores a salted password derivation and verifies it in constant-time form" do
    digest = PasswordHasher.create("Strong-Test-Password-2026!")

    assert_not_includes digest, "Strong-Test-Password-2026!"
    assert PasswordHasher.matches?(digest, "Strong-Test-Password-2026!")
    assert_not PasswordHasher.matches?(digest, "Another-Test-Password-2026!")
  end

  test "rejects short passwords" do
    assert_raises(ArgumentError) { PasswordHasher.create("too-short") }
  end
end
