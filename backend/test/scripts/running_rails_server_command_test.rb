require "test_helper"
require "open3"

class RunningRailsServerCommandTest < ActiveSupport::TestCase
  test "recognizes the default container command" do
    assert_detected("./bin/thrust", "./bin/rails", "server")
  end

  test "recognizes a Render command with server arguments" do
    assert_detected("./bin/thrust", "./bin/rails", "server", "--binding", "0.0.0.0", "--port", "10000")
  end

  test "does not prepare the database for a non-server command" do
    _output, _error, status = Open3.capture3(command_path, "./bin/rails", "runner", "puts(:ok)")

    assert_not status.success?
  end

  private

  def assert_detected(*arguments)
    _output, error, status = Open3.capture3(command_path, *arguments)

    assert status.success?, error
  end

  def command_path
    Rails.root.join("bin/running-rails-server-command").to_s
  end
end
