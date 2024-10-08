json.data do
  if params[:item_type_id].present? || @advanced_search_config.present?
    json.catalog_id params[:catalog_id]
    json.item_type_id params[:item_type_id]
    json.advanced_search do
      json.criteria do
        fields = @authenticated_catalog ? @fields : displayable_fields(@fields)
        fields.each_with_index do |field, _i|
          partial_path = "api/v3/catalog/advanced_searches/fields/#{field.partial_name}_search_field"
          next unless partial_exists? partial_path

          json.set! field.uuid do
            json.field_infos do
              json.id field.id
              json.type field.short_type_name
              json.set! "name_#{field.catalog.primary_language}", field.public_send("name_#{field.catalog.primary_language}")
            end
            json.criterion_content do
              json.partial! partial: partial_path, locals: { field: field }
            end
          end
        end
      end
    end
  end
end
