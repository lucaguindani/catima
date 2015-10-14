module CatalogAdmin::UsersHelper
  def setup_catalog_users_nav_link
    active = (params[:controller] == "catalog_admin/users")
    klass = "list-group-item"
    klass << " active" if active

    link_to("Users", catalog_admin_users_path, :class => klass)
  end

  def user_role(user)
    return "Admin" if user.system_admin?

    options = CatalogPermission::ROLE_OPTIONS.reverse
    options.delete("reviewer") unless catalog.requires_review?

    role = options.find do |each|
      user.catalog_role_at_least?(catalog, each)
    end
    role.to_s.titleize
  end

  def render_catalog_admin_users_permission(form)
    render(
      :partial => "catalog_admin/users/nested_permission",
      :locals => {
        :f => form,
        :perm => sorted_permissions_for_edit(form.object, [catalog]).first
      })
  end
end