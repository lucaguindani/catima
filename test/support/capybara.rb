# Capybara + poltergeist allow JS testing via headless webkit
require "capybara/rails"
require "capybara/poltergeist"
Capybara.javascript_driver = :poltergeist

class ActionDispatch::IntegrationTest
  # Make the Capybara DSL available in all integration tests
  include Capybara::DSL

  setup do
    Capybara.use_default_driver
    Capybara.current_session.driver.browser.clear_cookies
  end

  def use_javascript_capybara_driver
    Capybara.current_driver = Capybara.javascript_driver
    Capybara.current_session.driver.browser.clear_cookies
  end
end

# Monkey patch so that AR shares a single DB connection among all threads.
# This ensures data consistency between the test thread and poltergeist thread.
class ActiveRecord::Base
  mattr_accessor :shared_connection
  @@shared_connection = nil

  def self.connection
    @@shared_connection || ConnectionPool::Wrapper.new(:size => 1) { retrieve_connection }
  end
end
ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection
