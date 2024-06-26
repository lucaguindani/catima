require "test_helper"

class FieldsTest < ActionDispatch::IntegrationTest
  include ItemReferenceHelper

  test "create and view item with a compound field" do
    log_in_as("one-admin@example.com", "password")
    visit("/one/en/admin/authors/fields")

    click_on("Compound field")
    fill_in("field[name_en]", :with => "Test")
    fill_in("field[name_plural_en]", :with => "Tests")
    fill_in("Slug (singular)", :with => "test")
    first('input#field_template', visible: false).set('{"en":"{{name}}:{{age}}"}')
    click_on("Create field")

    visit("/one/en/authors")
    click_on("Stephen King")
    assert(page.has_content?("Stephen King:68"))
  end

  test "create and view item with an embed field" do
    log_in_as("two-admin@example.com", "password")
    visit("/two/en/admin/twos/fields")

    click_on("Embed field")
    fill_in("field[name_en]", :with => "Test")
    fill_in("field[name_plural_en]", :with => "Tests")
    fill_in("Slug (singular)", :with => "test")
    select("url", :from => "Format")
    fill_in("Iframe width", :with => 360)
    fill_in("Iframe height", :with => 360)
    click_on("Create field")

    click_on("Data")
    click_on('Twos 2')
    click_on("New Two")
    fill_in('Test', with: 'https://www.youtube.com/embed/C3-skAbrO2g')
    click_on("Create Two")
    click_on("Return to site")

    within('.nav.navbar-nav.me-auto') do
      click_on("Twos")
    end

    within('.container') do
      all(:css, 'a').last.click
    end

    assert(page.has_selector?("iframe"))
    assert_equal("https://www.youtube.com/embed/C3-skAbrO2g", page.find('iframe')['src'])
  end

  test "view item with editor" do
    book = items(:one_book_theory_of_relativity)
    visit("/one/en/other-books/#{book.to_param}")

    within("body>.container") do
      assert(page.has_content?(book.creator.email))
    end
  end

  test "view item with editor and updater" do
    book = items(:one_book_theory_of_relativity)
    visit("/one/en/other-books/#{book.to_param}")

    within("body>.container") do
      assert(page.has_content?(book.creator.email))
      assert(page.has_content?('Updated by'))
    end
  end

  test "view item with editor and timestamps" do
    book = items(:one_book_theory_of_relativity)
    visit("/one/en/other-books/#{book.to_param}")

    within("body>.container") do
      assert(page.has_content?(book.creator.email))
      assert(page.has_content?(Time.current.year.to_s))
    end
  end

  test "view item with editor, updater and timestamps" do
    book = items(:one_book_theory_of_relativity)
    visit("/one/en/other-books/#{book.to_param}")

    within("body>.container") do
      assert(page.has_content?(book.creator.email))
      assert(page.has_content?('Updated by'))
      assert(page.has_content?(Time.current.year.to_s))
    end
  end

  test "view item with deleted editor" do
    visit("/one/en/other-books/#{items(:one_book_mister_nobody).to_param}")

    within("body>.container") do
      assert(page.has_content?(users(:one_user_deleted).email))
    end
  end
end
