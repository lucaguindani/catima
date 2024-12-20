# == Schema Information
#
# Table name: item_types
#
#  catalog_id               :integer
#  created_at               :datetime         not null
#  deleted_at           :datetime
#  display_emtpy_fields     :boolean          default(TRUE), not null
#  id                       :integer          not null, primary key
#  name_plural_translations :json
#  name_translations        :json
#  seo_indexable            :boolean          default(TRUE), not null
#  slug                     :string
#  updated_at               :datetime         not null
#

require_dependency 'field/choice_set'

class ItemType < ApplicationRecord
  include HasFields
  include HasTranslations
  include HasSlug
  include HasSQLSlug
  include Loggable
  include HasDeletion
  include Clone

  has_many :items
  has_many :item_views, :dependent => :destroy
  has_many :menu_items, :dependent => :destroy
  has_many :advanced_search_configurations, :dependent => :destroy
  has_many :suggestions, dependent: :destroy

  store_translations :name, :name_plural

  validates_slug :scope => [:catalog_id, :deleted_at]
  validate :pages_slug_validation
  validates_presence_of :suggestion_email, if: :suggestions_activated?

  alias_method :log_name, :name

  def self.sorted(locale=I18n.locale)
    order(Arel.sql("LOWER(item_types.name_translations->>'name_#{locale}') ASC"))
  end

  # An array of all fields in this item type, plus any nested fields included
  # by way of categories. Note that this only descends one level: it does not
  # recurse.
  def all_fields
    return @all_fields if defined? @all_fields

    @all_fields ||= fields.includes(field_set: [:catalog]).each_with_object([]) do |field, all|
      all << field
      next unless field.is_a?(Field::ChoiceSet)

      field.choices.includes(:category).each do |choice|
        category = choice.category
        next unless category&.not_deleted?

        additional_fields = category.fields.includes(field_set: [:catalog]).map do |f|
          f.category_choice = choice
          f.category_choice_set = field.choice_set
          f
        end
        all.concat(additional_fields)
      end
    end
  end

  # Same as all_fields, but limited to display_in_list=>true.
  def all_list_view_fields
    return @all_list_view_fields if defined? @all_list_view_fields

    @all_list_view_fields ||= all_fields.select(&:display_in_list)
  end

  # Same as all_fields, but limited to display_in_public_list=>true.
  def all_public_list_view_fields
    return @all_public_list_view_fields if defined? @all_public_list_view_fields

    @all_public_list_view_fields ||= all_fields.select(&:display_in_public_list)
  end

  # Same as all_list_view_fields, but limited human_readable?.
  def sortable_list_view_fields
    return @sortable_list_view_fields if defined? @sortable_list_view_fields

    @sortable_list_view_fields ||= all_list_view_fields.select(&:human_readable?)
  end

  def primary_field
    return @primary_field if defined? @primary_field

    @primary_field ||= fields.to_a.find(&:primary?)
  end

  # Field most appropriate for describing this item. This is usually the
  # primary field, but may be something different if the primary field is
  # not defined. Restricted fields or fields that are not human_readable
  # wont be suitable candidates.
  def field_for_select
    candidate_fields = [primary_field, list_view_fields, fields].flatten.compact
    candidate_fields.reject(&:restricted?).find(&:human_readable?)
  end

  # Fields that are filterable
  def simple_fields
    fields.select(&:filterable?)
  end

  # The primary or first text field. Used to generate Item slugs.
  def primary_text_field
    return @primary_text_field if defined? @primary_text_field

    @primary_text_field = begin
      candidate_fields = [primary_field, list_view_fields, fields].flatten.compact
      candidate_fields.reject(&:restricted?).find { |f| f.is_a?(Field::Text) }
    end
  end

  def public_items
    items.merge(catalog.public_items)
  end

  def public_sorted_items
    public_items.merge(sorted_items)
  end

  def sorted_items
    items.sorted_by_field(primary_field)
  end

  # Finds a field based on the slug or UUID
  def find_field(field_id)
    fields.find_by(field_id.starts_with?('_') ? :uuid : :slug => field_id)
  end

  def default_list_view
    item_views.find_by(default_for_list_view: true)
  end

  def default_item_view
    item_views.find_by(default_for_item_view: true)
  end

  def default_display_name_view
    item_views.find_by(default_for_display_name: true)
  end

  def include_geographic_field?
    fields.each do |field|
      return true if field.type == Field::TYPES["geometry"]
    end

    false
  end

  # Return if the field_set is disabled for SEO indexing.
  # Return false if the catalog is not SEO indexable, even if the field_set is.
  def seo_indexable_disabled?
    catalog.seo_indexable && !seo_indexable
  end

  private

  # A page & an item type should not have the same slug
  # because they have the same path structure. It could
  # lead to unpredictable behavior
  def pages_slug_validation
    return unless catalog

    return unless catalog.pages.exists?(slug: slug)

    errors.add :slug, I18n.t("validations.item_type.pages_slug")
  end
end
