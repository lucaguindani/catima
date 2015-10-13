module Admin::ItemTypesHelper
  def setup_item_type_nav_link(item_type)
    slug = params[:item_type_slug] || params[:slug]
    active = params[:controller] =~ /item_types|fields/ &&
             slug == item_type.slug

    klass = "list-group-item"
    klass << " active" if active

    link_to(
      item_type.name,
      catalog_admin_item_type_fields_path(item_type.catalog, item_type),
      :class => klass
    )
  end
end
