class API::V3::CatalogPolicy < CatalogPolicy
  include CatalogAdmin::CatalogsHelper

  def initialize(user, catalog)
    super
    raise Pundit::NotAuthorizedError unless catalog.not_deactivated?
  end

  def user_requirements_according_to_visibility?
    return true if user.system_admin?

    case catalog_access(catalog)
    when CatalogAdmin::CatalogsHelper::CATALOG_ACCESS[:open_for_everyone]
      # Access to everyone
      true
    when CatalogAdmin::CatalogsHelper::CATALOG_ACCESS[:open_to_members]
      # Access to members
      user_is_at_least_a_member?
    when CatalogAdmin::CatalogsHelper::CATALOG_ACCESS[:open_to_catalog_staff]
    else
      # Access to catalog staff
      user_is_at_least_an_editor?
    end
  end

  # Catalog
  alias_method :index?, :user_is_catalog_admin?
  alias_method :categories_index?, :user_is_catalog_admin?
  alias_method :choice_sets_index?, :user_is_catalog_admin?
  alias_method :groups_index?, :user_is_catalog_admin?
  alias_method :users_index?, :user_is_catalog_admin?
  alias_method :item_types_index?, :user_is_at_least_an_editor?
  alias_method :suggestions_index?, :user_is_at_least_an_editor?

  # Category
  alias_method :category_fields_index?, :user_is_catalog_admin?

  # ChoiceSet
  alias_method :choice_set_choices_index?, :user_is_catalog_admin?
  alias_method :choice_set_choice_show?, :user_is_catalog_admin?

  # ItemType
  alias_method :item_type_fields_index?, :user_is_catalog_admin?
  alias_method :item_type_items_index?, :user_requirements_according_to_visibility?
  alias_method :item_type_show?, :user_is_at_least_an_editor?
  alias_method :item_type_field_show?, :user_is_catalog_admin?
  alias_method :item_type_item_show?, :user_requirements_according_to_visibility?
  alias_method :item_type_item_suggestions?, :user_is_at_least_an_editor?

  # SimpleSearch
  alias_method :simple_search_create?, :user_requirements_according_to_visibility?
  alias_method :simple_search_show?, :user_requirements_according_to_visibility?

  # AdvancedSearch
  alias_method :advanced_search_new?, :user_requirements_according_to_visibility?
  alias_method :advanced_search_create?, :user_requirements_according_to_visibility?
  alias_method :advanced_search_show?, :user_requirements_according_to_visibility?
end
