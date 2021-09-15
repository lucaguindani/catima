class API::V3::Catalog::UsersController < API::V3::Catalog::BaseController
  include CatalogAdmin::CatalogsHelper

  after_action -> { set_pagination_header(:users) }, only: :index

  def index
    authorize(@catalog, :users_index?) unless authenticated_catalog?

    @users = User.where(id: @catalog.user_with_role_in(%w[member editor super-editor reviewer admin]))
                 .or(User.where(id: @catalog.groups.where(active: true).select { |g|
                   case catalog_access(@catalog)
                   when 1
                     true
                   when 2
                     g.catalog_permissions.last.role_at_least?("member")
                   else
                     g.catalog_permissions.last.role_at_least?("editor")
                   end
                 }.flat_map(&:user_ids)))
                 .page(params[:page]).per(params[:per])
  end
end