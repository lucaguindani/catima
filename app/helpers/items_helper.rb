# == Schema Information
#
# Table name: items
#
#  catalog_id     :integer
#  created_at     :datetime         not null
#  creator_id     :integer
#  data           :json
#  id             :integer          not null, primary key
#  item_type_id   :integer
#  review_status  :string           default("not-ready"), not null
#  reviewer_id    :integer
#  search_data_de :text
#  search_data_en :text
#  search_data_fr :text
#  search_data_it :text
#  updated_at     :datetime         not null
#

module ItemsHelper
  def browse_similar_items_link(label, item, field, value, html_options: {})
    link_to(
      label,
      items_path(
        :catalog_slug => item.catalog,
        :item_type_slug => item.item_type,
        :locale => I18n.locale,
        field.slug => value
      ),
      html_options)
  end

  def item_has_thumbnail?(item, options={})
    options[:public_only] ? item_public_image_field(item) : item_displayable_image_field(item)
  end

  def item_thumbnail(item, options={})
    field = options[:public_only] ? item_public_image_field(item) : item_displayable_image_field(item)
    field_value(item, field, options.reverse_merge(:style => :compact)) if field
  end

  # Returns the first user displayable image field with files, or nil
  def item_displayable_image_field(item)
    item.fields.find do |f|
      f.is_a?(Field::Image) &&
        f.display_in_public_list &&
        f.displayable_to_user?(current_user) &&
        f.file_count(item) > 0
    end
  end

  # Returns the first non-restricted & public image field with files, or nil
  def item_public_image_field(item)
    item.fields.find do |f|
      f.is_a?(Field::Image) &&
        f.display_in_public_list &&
        !f.restricted? &&
        f.file_count(item) > 0
    end
  end

  def item_list_view(item, options={})
    item_view = item.item_type.default_list_view
    return item_display_name(item) if item_view.nil?

    presenter = ItemViewPresenter.new(self, item_view, item, I18n.locale, options)
    presenter.render(:list_view)
  end

  def item_summary(item, bypass_displayable: false)
    # Retrieve all applicable fields for the summary & join the values
    item.applicable_list_view_fields.each_with_object([]) do |fld, html|
      # Remove field if restricted
      next unless bypass_displayable || fld.displayable_to_user?(current_user)

      # Remove field if primary
      next if fld == item.primary_field

      # Remove field if non human readable unless is filterable
      next unless fld.human_readable? || fld.filterable?

      # Remove all html tags
      value = strip_tags(field_value(item, fld, :style => :compact, :no_links => true))

      # Remove field if value is blank
      next if value.blank?

      html << [tag.b("#{fld.name}:"), value].join(" ")
    end.join("; ").html_safe
  end

  def item_display_name(item)
    item_view = item.item_type.default_display_name_view
    return default_display_name(item) if item_view.nil?

    presenter = ItemViewPresenter.new(self, item_view, item, I18n.locale, strip_p: true)
    presenter.render(:display_name)
  end

  def default_display_name(item)
    field = item.field_for_select
    return item.id.to_s if field.nil?

    Loofah.fragment(
      field_value(item, field, :style => :compact)
    ).text(encode_special_chars: false) || ''.html_safe
  end

  def formatted_item_for_line(item, list:, sort_field:)
    html_title = tag.h4(item_list_link(list, item, nil, item_display_name(item)), class: "mt-0 mb-1")
    html_thumbnail = tag.div(item_list_link(list, item, nil) { item_thumbnail(item, :class => "media-object") }, class: "pull-left me-3") if item_has_thumbnail?(item)

    item.attributes.merge(
      title: html_title,
      thumbnail: html_thumbnail,
      summary: item_summary(item),
      primary_field_value: field_value(item, item.item_type.field_for_select),
      sort_field_value: sort_field_value(sort_field, item),
      group_title: sort_field.is_a?(Field::DateTime) ? Field::DateTimePresenter.new(nil, item, sort_field).value(format: sort_field.format) : field_value(item, sort_field)
    )
  end

  def sort_field_value(sort_field, item)
    case sort_field
    when Field::DateTime
      sort_field.raw_value(item) || {}
    when Field::ChoiceSet
      sort_field.selected_choices(item)
                .map(&:short_name)
                .join(" ")
    else
      field_value(item, sort_field)
    end
  end

  def group_items_for_line(items, sort_field:)
    return group_item_by_date_time_field(items, sort_field) if sort_field.is_a?(Field::DateTime)
    return { items: group_item_numerically(items) } if sort_field.is_a?(Field::Int)

    { items: group_item_alphabetically(items) }
  end

  def group_item_numerically(items)
    items.group_by { |item| item[:sort_field_value] }.transform_values do |v|
      v.group_by { |i| i[:sort_field_value] }
    end
  end

  def group_item_alphabetically(items)
    items.group_by { |item| strip_tags(item[:sort_field_value])&.strip&.first&.upcase }.transform_values do |v|
      v.group_by { |i| strip_tags(i[:sort_field_value])&.strip }
    end
  end

  def group_item_by_date_time_field(items, field)
    criteria = field.format.chars.first(4)
    recursive_group_by_criteria({ items: items }, criteria)
  end

  def recursive_group_by_criteria(items_object, criteria)
    return items_object if criteria.empty?

    items_object.transform_values do |v|
      recursive_group_by_criteria(group_by_criteria(v, criteria), criteria.drop(1))
    end
  end

  def group_by_criteria(items, criteria)
    hash = items.group_by do |item|
      item[:sort_field_value][criteria.first]
    end
    hash[' '] = hash.delete('') if hash.key?('')
    hash[' '] = hash.delete(nil) if hash.key?(nil)
    hash
  end

  # Check that the referer is the item type list (Data mode)
  # of the same item type
  def referer_with_same_item_type?(item)
    return false unless request.referer

    referer = Rails.application.routes.recognize_path(URI(request.referer).path, method: :post)
    return false if referer.key?(:id)

    return false unless referer.key?(:item_type_slug)

    referer[:item_type_slug].eql? item.item_type.slug
  rescue StandardError
    false
  end

  def meta_tag_description_for_items(item)
    return if item_display_name(item).blank?

    tag.meta(
      name: "description",
      content: strip_tags("#{item.catalog.name} - #{item_display_name(item)}")
    )
  end
end
