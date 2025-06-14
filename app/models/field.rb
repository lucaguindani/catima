# == Schema Information
#
# Table name: fields
#
#  category_item_type_id    :integer
#  choice_set_id            :integer
#  comment                  :text
#  created_at               :datetime         not null
#  default_value            :text
#  display_component        :string
#  display_in_list          :boolean          default(TRUE), not null
#  display_in_public_list   :boolean          default(TRUE), not null
#  editor_component         :string
#  field_set_id             :integer
#  field_set_type           :string
#  i18n                     :boolean          default(FALSE), not null
#  id                       :integer          not null, primary key
#  multiple                 :boolean          default(FALSE), not null
#  name_plural_translations :json
#  name_translations        :json
#  options                  :json
#  ordered                  :boolean          default(FALSE), not null
#  primary                  :boolean          default(FALSE), not null
#  related_item_type_id     :integer
#  required                 :boolean          default(FALSE), not null
#  restricted               :boolean          default(FALSE), not null
#  row_order                :integer
#  slug                     :string
#  type                     :string
#  unique                   :boolean          default(FALSE), not null
#  updated_at               :datetime         not null
#  uuid                     :string
#

# rubocop:disable Metrics/ClassLength
class Field < ApplicationRecord
  TYPES = {
    "boolean" => "Field::Boolean",
    "choice" => "Field::ChoiceSet",
    "datetime" => "Field::DateTime",
    "decimal" => "Field::Decimal",
    "email" => "Field::Email",
    "editor" => "Field::Editor",
    "file" => "Field::File",
    "geometry" => "Field::Geometry",
    "image" => "Field::Image",
    "int" => "Field::Int",
    "reference" => "Field::Reference",
    "text" => "Field::Text",
    "url" => "Field::URL",
    # "xref" => "Field::Xref", disabled, uncomment to enable it
    "compound" => "Field::Compound",
    "embed" => "Field::Embed",
    "complex_datation" => "Field::ComplexDatation"
  }.freeze

  include ActionView::Helpers::SanitizeHelper
  include Field::Style
  include HasTranslations
  include HasSlug
  include HasSQLSlug
  include RankedModel
  include FieldsHelper
  include JsonHelper
  include Loggable

  ranks :row_order, :class_name => "Field", :with_same => :field_set_id

  delegate :catalog, :to => :field_set, :allow_nil => true
  delegate :component_choice?, :components_are_valid, :component_choices,
           :assign_default_components,
           :to => :component_config

  belongs_to :field_set, :polymorphic => true

  store_translations :name, :name_plural

  attr_accessor :category_choice, :category_choice_set

  validates_presence_of :field_set
  validate :default_value_passes_field_validations
  validate :components_are_valid
  validates_slug :scope => :field_set_id

  before_validation :assign_default_components
  before_create :assign_uuid
  # TODO: uncomment when item cache worker is fixed
  # Recreate cache only if the primary attribute has changed
  # after_update :recreate_cache if saved_changes.include?(:primary)
  after_save :remove_primary, :if => :primary?
  after_save(
    :remove_display_in_public_list,
    :if => :display_in_public_list?,
    :unless => :displayable_in_public_list?
  )

  def log_name
    slug
  end

  def self.sorted
    rank(:row_order)
  end

  def self.policy_class
    FieldPolicy
  end

  def self.type_choices
    Field::TYPES.map do |key, class_name|
      [key, class_name.constantize.new.type_name]
    end.sort_by(&:last)
  end

  alias_method :item_type, :field_set

  def belongs_to_category?
    !!category_id
  end

  # Whether or not a field is displayable to a user for a specific catalog.
  #
  # A restricted field should not be displayed if the user is not a staff
  # (>= editor) of the current catalog
  def displayable_to_user?(user, cat=catalog)
    at_least_editor = user.catalog_role_at_least?(cat, 'editor')
    at_least_editor || !restricted?
  end

  def category_id
    field_set.is_a?(Category) ? field_set.id : nil
  end

  def category_choice_id
    field_set.is_a?(Category) ? category_choice&.id : nil
  end

  def category_choice_set_id
    field_set.is_a?(Category) ? category_choice_set&.id : nil
  end

  def type_name
    type.gsub("Field::", "")
  end

  def short_type_name
    ::Field::TYPES.to_a.rassoc(self.class.to_s).first
  end

  def partial_name
    model_name.singular.sub(/^field_/, "")
  end

  def custom_field_permitted_attributes
    []
  end

  def custom_item_permitted_attributes
    []
  end

  def label
    multiple? ? name_plural : name
  end

  # Whether or not this field holds a human-readable value, e.g. text, number,
  # etc. An image or geometry would not qualify, as those are displayed as non-
  # text. Any field that uses a display_component would not qualify, because the
  # field is rendered via JavaScript.
  #
  # Default depends on the presence of display_component, and subclasses can
  # override.
  #
  def human_readable?
    display_component.blank?
  end

  # Whether or not this field is groupable.
  #
  # Default depends on the human_readable method result, cannot be multiple, and subclasses can
  # override.
  #
  # Mainly used for the sort field of the "line" style in an ItemType container.
  def groupable?
    return false if multiple?

    human_readable?
  end

  # Whether or not this field is sortable.
  #
  # Default depends on the human_readable method result, cannot be multiple, and subclasses can
  # override.
  #
  # Mainly used for the sort field of the ItemType container.
  def sortable?
    return false if multiple?

    human_readable?
  end

  # Whether or not this field is filterable. Can be used in addition to the human_readable?
  # method.
  #
  # Default depends on the human_readable method result, and subclasses can override.
  #
  # Mainly used in advanced search configuration and ui.
  def filterable?
    human_readable?
  end

  # Whether or not this field supports the `multiple` option. This method exists so that
  # the UI can show or hide the appropriate configuration controls for the field.
  # Subclasses may override.
  def allows_multiple?
    false
  end

  # Whether or not this field supports the `style` options. Subclasses may override.
  def allows_style?
    true
  end

  # Whether or not this field supports the `unique` option. Subclasses may override.
  def allows_unique?
    true
  end

  # Whether or not this field can be displayed in the public list view.
  # Override for allowing a field to be displayed in the public list view
  # although it's not human readable nor filterable.
  def displayable_in_public_list?
    return true if human_readable?

    true if filterable?
  end

  def raw_value(item, locale=I18n.locale, suffix="")
    return nil unless applicable_to_item(item)

    attrib = i18n? ? "#{uuid}_#{locale}#{suffix}" : uuid
    item.behaving_as_type.public_send(attrib)
  end

  def raw_json_value(item, locale=I18n.locale)
    raw_value(item, locale, "_json")
  end

  # Takes the input value and tries to prepare value for setting the field.
  # This can be a localized hash, or a hash describing a referenced item.
  # It returns a hash that can be used to update the item with the correct
  # field uuids.
  def prepare_value(value)
    {uuid => value}
  end

  # Returns additional properties for React for editing component
  def edit_props(_item)
    {}
  end

  # Returns additional properties for React for viewing component
  def view_props
    {}
  end

  # Tests whether this field is appropriate to display/validate for the given
  # item. This only makes sense for category fields. For non-category fields,
  # always returns true.
  def applicable_to_item(item)
    return true unless belongs_to_category?

    item.fields.any? do |field|
      next unless field.is_a?(ChoiceSet)

      choice = field.selected_choice(item)
      choice && choice.category_id == category_id
    end
  end

  # Returns a JSON description of this field. By default, it returns all
  # attributes. Subclasses can override this method to provide a more
  # specific description.
  def describe
    as_json(only:
              %i[
                type uuid slug name_translations
                name_plural_translations comment default_value primary
                required unique options display_in_list display_in_public_list
              ]
           ).merge(allows_multiple? ? as_json(only: [:multiple]) : {})
  end

  # Returns the field value for a given item
  # For simple field types, it returns the database representation
  # For more complex field types, it returns the item type instance,
  # or another adapted representation. In this case, this method
  # is overridden by the field subclasses.
  def value_for_item(it)
    it.data[uuid]
  end

  def value_or_id_for_item(it)
    value_for_item(it)
  end

  def field_value_for_item(it)
    raw_value(it) if human_readable?
  end

  # Even non readable. Useful for dumps
  def csv_value(it, _user=nil)
    raw_value(it)
  end

  # Defines methods and runs class macros on the given item class in order to
  # add validation rules, accessors, etc. for this field. The class in this
  # case is an anonymous subclass of Item.
  def decorate_item_class(klass)
    klass.data_store_attribute(uuid, :i18n => i18n?, :multiple => multiple?, :transformer => method(:transform_value))

    # TODO: how does validation work for multi-valued?
    validators = build_validators
    validators << ActiveModel::Validations::PresenceValidator if required?

    validators.each do |val|
      val = Array.wrap(val)
      options = val.extract_options!
      klass.data_store_validator(uuid, val.first, options, :i18n => i18n?, :prerequisite => method(:applicable_to_item))
    end
  end

  # Remove html tags & base64 from field content
  def strip_extra_content(item, locale=I18n.locale)
    value = raw_value(item, locale)
    # Remove base64 content
    value = exclude_base64(value)
    # Insert spaces after specific tags to preserve word boundaries
    value = value.gsub(%r{</?(p|div|br|li|h[1-6]|tr|td|th)[^>]*>}i, ' ')
    # Strip HTML tags
    value = strip_tags(value)
    # Remove extra spaces
    value.strip.gsub(/\s+/, ' ')
  end

  # Returns the order by for items with a sort by a field
  def order_items_by(direction: 'ASC', nulls_order: 'LAST')
    "NULLIF(items.data->>'#{uuid}', '') #{direction} NULLS #{nulls_order}"
  end

  def order_items_by_primary_field
    "items.data->>'#{item_type.field_for_select.uuid}'"
  end

  # Useful for the advanced search
  def search_conditions_as_options
    [
      [I18n.t("advanced_searches.text_search_field.all_words"), "all_words"],
      [I18n.t("advanced_searches.text_search_field.one_word"), "one_word"],
      [I18n.t("advanced_searches.text_search_field.exact"), "exact"]
    ]
  end

  # Useful for the advanced search. Subclasses can
  # override.
  def search_conditions_as_hash(locale)
    [
      { :value => I18n.t("advanced_searches.text_search_field.all_words", locale: locale), :key => "all_words"},
      { :value => I18n.t("advanced_searches.text_search_field.one_word", locale: locale), :key => "one_word"},
      { :value => I18n.t("advanced_searches.text_search_field.exact", locale: locale), :key => "exact"}
    ]
  end

  # Useful for the advanced search. Subclasses can
  # override.
  def search_field_conditions_as_hash
    [
      { :value => I18n.t("and"), :key => "and"},
      { :value => I18n.t("or"), :key => "or"},
      { :value => I18n.t("exclude"), :key => "exclude"}
    ]
  end

  def search_data_as_hash
  end

  def search_options_as_hash
  end

  def sort_field?
    !is_a?(Field::ChoiceSet) && !is_a?(Field::Reference) && human_readable?
  end

  def sql_type
    "TEXT"
  end

  def sql_nullable
    "#{'NOT ' if required}NULL"
  end

  def sql_unique
    # MEDIUMTEXT can't be unique because MySQL doesn't know how many characters it has
    "UNIQUE" if unique && sql_type != "MEDIUMTEXT" && sql_type != "JSON"
  end

  def sql_default
    return "" if default_value.blank?

    "DEFAULT '#{default_value}'"
  end

  def sql_value(item)
    raw_value(item)
  end

  def sql_escape_formatted(value)
    value.to_s.gsub('\"') { '\\\"' }.gsub("'") { "\\'" }
  end

  private

  def exclude_base64(string)
    return '' if string.blank?
    return '' unless string.instance_of? String

    string.gsub(%r{data:image/([a-zA-Z]*);base64,([^"]*)"}, '')
  end

  def component_config
    @_component_config ||= ComponentConfig.new(self)
  end

  def build_validators
    []
  end

  def default_value_passes_field_validations
    build_validators.each do |val|
      val = Array.wrap(val)
      options = val.extract_options!
      validates_with(
        val.first,
        options.merge(
          :attributes => :default_value
        )
      )
    end
  end

  # Used as the key in the `data` JSON to store the value for this field.
  # For compatibility with third-party gems (e.g. refile), it has to be valid
  # as a Ruby instance variable name (letters, numbers, underscores; can't
  # start with a number).
  def assign_uuid
    self.uuid ||= "_#{SecureRandom.uuid.tr('-', '_')}"
  end

  def remove_primary
    # Remove primary if current field is not human readable
    return update(:primary => false) unless human_readable?

    # Remove primary if current field is restricted
    return update(:primary => false) if restricted?

    # Remove primary from other fields if current field is human readable
    field_set.fields.where.not(fields: { id: id }).update_all(:primary => false)
  end

  def remove_display_in_public_list
    update(:display_in_public_list => false)
  end

  def recreate_cache
    ItemsCacheWorker.perform_async(catalog.slug, item_type.slug)
  end

  def remove_default_value
    update(:default_value => nil) if default_value?
  end

  def transform_value(value)
    value
  end
end

# rubocop:enable Metrics/ClassLength
