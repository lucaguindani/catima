module VisibilityHelper
  def visibility_status_label(catalog)
    return nil unless catalog.not_deactivated?

    case catalog_access(catalog)
    when 2
      text = 'Members'
      klass = 'warning'
    when 3
      text = 'Catalog staff'
      klass = 'danger'
    else
      text = 'Everyone'
      klass = 'success'
    end

    tag.span(text, :class => "badge text-bg-#{klass}")
  end
end
