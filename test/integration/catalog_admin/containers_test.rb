require "test_helper"

class CatalogAdmin::ContainersTest < ActionDispatch::IntegrationTest
  setup { use_javascript_capybara_driver }

  test "create a container" do
    log_in_as("one-admin@example.com", "password")
    visit("/one/en/admin")
    click_on("Setup")
    click_on('Pages')
    click_on('New page')

    fill_in('Slug', :with => 'container-test')
    find('div.translatedTextField input[data-locale=en]').base.send_keys("Container test page")
    click_on('Create page')

    visit('/one/en/container-test')
    within('h1') { assert(page.has_content?('Container test page')) }

    click_on('Edit this page')
    find("#add-field-dropdown").click
    click_on('Markdown')

    fill_in('Slug', :with => 'test-md')
    fill_in('Markdown', :with => '**Bold text**')
    click_on('Create container')
    assert(page.has_content?('The “test-md” container has been created.'))

    new_window = window_opened_by { click_on("View page") }
    within_window new_window do
      within('strong') { assert(page.has_content?('Bold text')) }
    end
  end

  test "creates a contact container" do
    log_in_as("one-admin@example.com", "password")
    visit('/one/en/one-page')

    click_on('Edit this page')
    find("#add-field-dropdown").click
    click_on('Contact')

    fill_in('Slug', :with => 'test-contact')
    fill_in('Receiving email', :with => 'test@email.ch')
    click_on('Create container')

    new_window = window_opened_by { click_on("View page") }
    within_window new_window do
      assert(page.has_css?('input#name'))
      assert(page.has_css?('input#email'))
      assert(page.has_css?('input#subject'))
      assert(page.has_css?('textarea#body'))
    end
  end

  test "creates a search container" do
    log_in_as("one-admin@example.com", "password")
    visit("/one/en/admin/_pages/one-page/edit")

    find("#add-field-dropdown").click
    click_on("Search")

    fill_in("Slug", :with => "book-search")
    select("list", :from => "Style")
    select("book search", :from => "Saved search")
    click_on("Create container")

    new_window = window_opened_by { click_on("View page") }
    within_window new_window do
      assert(page.has_content?("Stephen"))
    end
  end

  test "cannot create two itemlist containers in the same page" do
    log_in_as("one-admin@example.com", "password")
    visit("/one/en/admin/_pages/one-fdesc/edit")

    find("#add-field-dropdown").click
    click_on("ItemList")

    click_on("Create container")

    assert(page.has_content?('Multiple "ItemList" containers in the same page is not allowed'))
  end

  test "map containers display correct geofield options" do
    log_in_as("one-admin@example.com", "password")
    visit("one/en/admin/_pages/line-one/edit")

    find("#add-field-dropdown").click
    click_on("Map")

    # We should see the geofields from book (the default one selected).
    within(".mb-3:has(#container_geofields)") do
      find(".basic-multi-select").click
      assert(page.has_content?('Birthplace'))
      assert(page.has_content?('Home'))
    end

    # # Select another item type.
    select "Book", from: "Item type"

    # Now we should see the geofields from author.
    within(".mb-3:has(#container_geofields)") do
      find(".basic-multi-select").click
      assert(page.has_content?("Location"))
    end
  end
end
