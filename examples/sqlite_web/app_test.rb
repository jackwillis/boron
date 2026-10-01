require "minitest/autorun"
require "boron"
require "rack/mock"
require "json"
require "tmpdir"
require "open3"

class SqliteWebTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("boron-web")
    @previous_database = ENV["BORON_DATABASE"]
    ENV["BORON_DATABASE"] = File.join(@directory, "test.sqlite3")
    @session = Boron::Session.new
    @session.environment.define("ARGV", [])
    path = File.join(__dir__, "app.bn")
    @session.evaluate(File.read(path), filename: path)
    @request = Rack::MockRequest.new(BoronDemo::App)
  end

  def teardown
    BoronDemo::User.connection_pool.disconnect! if defined?(BoronDemo::User)
    Object.send(:remove_const, :BoronDemo) if defined?(BoronDemo)
    ENV["BORON_DATABASE"] = @previous_database
    FileUtils.remove_entry(@directory)
  end

  def test_json_routes_and_database_rows
    response = @request.get("/users", "HTTP_HOST" => "localhost")
    assert_equal 200, response.status
    assert_match(/application\/json/, response["content-type"])
    assert_equal ["Ada", "Grace"], JSON.parse(response.body).map { |user| user.fetch("name") }
    assert_equal 2, BoronDemo::User.count
    assert File.file?(ENV.fetch("BORON_DATABASE"))
    health = @request.get("/health", "HTTP_HOST" => "localhost")
    assert_equal({"status" => "ok", "users" => 2}, JSON.parse(health.body))
    assert_equal 404, @request.get("/missing", "HTTP_HOST" => "localhost").status
  end

  def test_requests_observe_database_changes_and_restart_preserves_rows
    BoronDemo::User.create!(name: "Margaret")
    response = @request.get("/users", "HTTP_HOST" => "localhost")
    assert_equal ["Ada", "Grace", "Margaret"], JSON.parse(response.body).map { |user| user.fetch("name") }
    BoronDemo::User.connection_pool.disconnect!
    Object.send(:remove_const, :BoronDemo)
    path = File.join(__dir__, "app.bn")
    session = Boron::Session.new
    session.environment.define("ARGV", [])
    session.evaluate(File.read(path), filename: path)
    assert_equal 3, BoronDemo::User.count
  end

  def test_individual_user_route_uses_request_context_and_returns_json_404
    user = BoronDemo::User.order(:id).first
    response = @request.get("/users/#{user.id}", "HTTP_HOST" => "localhost")
    assert_equal 200, response.status
    assert_equal({"id" => user.id, "name" => "Ada"}, JSON.parse(response.body))
    missing = @request.get("/users/99999", "HTTP_HOST" => "localhost")
    assert_equal 404, missing.status
    assert_match(/application\/json/, missing["content-type"])
    assert_equal({"error" => "user not found"}, JSON.parse(missing.body))
    invalid = @request.get("/users/not-a-number", "HTTP_HOST" => "localhost")
    assert_equal 404, invalid.status
    assert_equal 2, BoronDemo::User.count
  end

  def test_compiled_app_runs_in_a_fresh_ruby_process
    source = File.join(__dir__, "app.bn")
    compiled = File.join(@directory, "app.rb")
    File.write(compiled, Boron::Compiler.new.compile(File.read(source), filename: source, standalone: true))
    script = <<~RUBY
      require #{compiled.dump}
      require "rack/mock"
      response = Rack::MockRequest.new(BoronDemo::App).get("/users", "HTTP_HOST" => "localhost")
      abort response.body unless response.status == 200
      puts response.body
    RUBY
    output, error, status = Open3.capture3(RbConfig.ruby, "-e", script)
    assert status.success?, error
    assert_equal ["Ada", "Grace"], JSON.parse(output).map { |user| user.fetch("name") }
  end
end
