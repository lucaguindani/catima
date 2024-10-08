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
#  required                 :boolean          default(TRUE), not null
#  restricted               :boolean          default(FALSE), not null
#  row_order                :integer
#  slug                     :string
#  type                     :string
#  unique                   :boolean          default(FALSE), not null
#  updated_at               :datetime         not null
#  uuid                     :string
#

class Field::DateTime < Field
  FORMATS = %w(Y M h YM MD hm YMD hms MDh YMDh MDhm YMDhm MDhms YMDhms).freeze

  store_accessor :options, :format
  after_initialize :set_default_format
  validates_inclusion_of :format, :in => FORMATS

  def type_name
    "Date time" + (persisted? ? " (#{format})" : "")
  end

  def custom_field_permitted_attributes
    %i(format)
  end

  # The Rails datetime form helpers submit components of the datetime as
  # individual attributes, like "#{uuid}_time(1i)", "#{uuid}_time(2i)", etc.
  # We need to explicitly permit them.
  def custom_item_permitted_attributes
    (1..6).map { |i| :"#{uuid}_time(#{i}i)" }
  end

  # Translates YMD.. hash into an array [Y, M, D, h, m, s] (or nil).
  def value_as_array(item, format: "YMDhms")
    value = raw_value(item)
    return nil if value.nil?

    defaults = {}
    format.each_char { |c| defaults[c] = "" }
    defaults.map do |key, default_value|
      value[key] || default_value
    end
  end

  # Translates YMD.. hash into an integer number (or nil).
  def value_as_int(item)
    components = value_as_array(item)
    return nil if components.nil?

    (0..(components.length - 1)).collect { |i| components[i].to_s.present? ? components[i] * (10**(10 - (2 * i))) : 0 }.sum
  end

  # The form provides the datetime values as hash like
  # { 2 => 12, 1 => 2015, 3 => 31 }. This method transforms this value
  # to the internal storage representation.
  def assign_value_from_form(item, values)
    time_hash = form_submission_as_time_hash(values)
    item.public_send("#{uuid}=", time_hash)
  end

  # Rails submits the datetime from the UI as a hash of component values,
  # e.g. { 2 => 12, 1 => 2015, 3 => 31 }
  # Translate the submission into an appropriate hash,
  # e.g. { "Y" => 2015, "M" => 12, "D" => 31 }
  def form_submission_as_time_hash(values)
    values = coerce_to_array(values)
    return nil if values.empty?

    # Discard precision not required by format
    values = values[0...format.length]

    # Pad out datetime components with default values, as needed
    defaults = [Time.current.year, 1, 1, 0, 0, 0]
    values += defaults[values.length..-1]

    k = %w(Y M D h m s)[0...format.length]
    (k.zip values).to_h
  end

  # To facilitate form helpers, we need to create a virtual attribute that
  # handles translation to and from the actual stored value. This virtual
  # attribute gets the name "#{uuid}_time".
  # Another virtual attribute allows retrieving the time value as an integer
  # value for date comparisons. This attribute is "#{uuid}_int".
  def decorate_item_class(klass)
    super
    field = self
    klass.send(:define_method, "#{uuid}_time") do
      field.value_as_array(self)
    end
    klass.send(:define_method, "#{uuid}_time=") do |values|
      field.assign_value_from_form(self, values)
    end
    klass.send(:define_method, "#{uuid}_int") do
      field.value_as_int(self)
    end
  end

  def field_value_for_item(it)
    field_value(it, self)
  end

  def order_items_by(direction: 'ASC', nulls_order: 'LAST')
    "NULLIF(items.data->'#{uuid}'->>'#{format[0]}', '')::bigint #{direction} NULLS #{nulls_order},
    (COALESCE(NULLIF(items.data->'#{uuid}'->>'Y', '')::bigint, 0) * 60 * 60 * 24 * (365 / 12) * 12 ) +
    (COALESCE(NULLIF(items.data->'#{uuid}'->>'M', '')::bigint, 0) * 60 * 60 * 24 * (365 / 12) ) +
    (COALESCE(NULLIF(items.data->'#{uuid}'->>'D', '')::bigint, 0) * 60 * 60 * 24 ) +
    (COALESCE(NULLIF(items.data->'#{uuid}'->>'h', '')::bigint, 0) * 60 * 60 ) +
    (COALESCE(NULLIF(items.data->'#{uuid}'->>'m', '')::bigint, 0) * 60 ) +
    (COALESCE(NULLIF(items.data->'#{uuid}'->>'s', '')::bigint, 0) ) #{direction}"
  end

  def search_conditions_as_hash(locale)
    [
      { :value => I18n.t("advanced_searches.fields.date_time_search_field.exact", locale: locale), :key => "exact" },
      { :value => I18n.t("advanced_searches.fields.date_time_search_field.after", locale: locale), :key => "after" },
      { :value => I18n.t("advanced_searches.fields.date_time_search_field.before", locale: locale), :key => "before" },
      { :value => I18n.t("advanced_searches.fields.date_time_search_field.between", locale: locale), :key => "between" },
      { :value => I18n.t("advanced_searches.fields.date_time_search_field.outside", locale: locale), :key => "outside" }
    ]
  end

  def search_options_as_hash
    [
      { :format => format },
      { :localizedDateTimeData => I18n.t('date') }
    ]
  end

  def csv_value(item, _user=nil)
    Field::DateTimePresenter.new(nil, item, self).value
  end

  def sql_type
    "JSON"
  end

  def edit_props(item)
    {
      errors: item[:item].errors.map do |error|
        {
          message: error.message,
          field: error.attribute
        }
      end
    }
  end

  private

  def transform_value(v)
    return nil if v.nil?
    return v if v.is_a?(Hash) && !v.key?("raw_value")

    v = { "raw_value" => v } if v.is_a?(Integer)
    v["raw_value"].nil? ? nil : v
  end

  def set_default_format
    self.format ||= "YMD"
  end

  def coerce_to_array(values)
    return [] if values.nil?
    return values if values.is_a?(Array)

    # Rails datetime form helpers send data as e.g. { 1 => "2015", 2 => "12" }.
    values.keys.sort.each_with_object([]) do |key, array|
      array << values[key]
    end.compact
  end

  def build_validators
    [DateTimeValidator]
  end

  class DateTimeValidator < ActiveModel::Validator
    def validate(record)
      attrib = Array.wrap(options[:attributes]).first
      value = record.public_send(attrib)
      field = Field.find_by(uuid: attrib)

      return if value.blank?
      return if value.is_a?(Hash) && value.has_key?("raw_value")
      return if value.keys.all? { |key| value[key].blank? || value[key].nil? } && !field.required

      if value.keys.all? { |key| value[key].blank? || value[key].nil? } && field.required
        record.errors.add(attrib, I18n.t('activerecord.errors.models.item.attributes.base.cant_be_blank'))
        return
      end

      allowed_formats = Field::DateTime::FORMATS.select { |f| field.format.include?(f) || field.format == f }
      current_format = field.format.chars.map { |char| value[char].blank? || value[char].nil? ? nil : char }.compact.join

      record.errors.add(attrib, I18n.t('activerecord.errors.models.item.attributes.base.wrong_format', field_format: allowed_formats)) unless allowed_formats.include?(current_format)
    end
  end
end
