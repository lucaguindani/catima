Rails.application.routes.draw do
  # ===========================================================================
  # API

  namespace :api, :format => "json", :only => %w(index show) do
    namespace :v1 do
      resources :catalogs, :param => :slug do
        resources :items
      end
    end
  end

  # ===========================================================================
  # Devise

  scope :path => ":locale" do
    devise_for :users, :skip => [:passwords, :registrations, :sessions]
    devise_scope :user do
      # passwords
      get "forgot-password" => "devise/passwords#new", :as => :new_user_password
      post "forgot-password" => "devise/passwords#create", :as => :user_password
      get "change-password" => "devise/passwords#edit",
          :as => :edit_user_password
      patch "change-password" => "devise/passwords#update"

      # registrations
      get "register" => "devise/registrations#new",
          :as => :new_user_registration
      post "register" => "devise/registrations#create",
          :as => :user_registration
      get "my-profile" => "devise/registrations#edit",
          :as => :edit_user_registration
      patch "my-profile" => "devise/registrations#update"
      get "cancel-account" => "devise/registrations#cancel",
          :as => :cancel_user_registration
      delete "cancel-account" => "devise/registrations#destroy"

      # sessions
      get "login" => "users/sessions#new", :as => :new_user_session
      post "login" => "users/sessions#create", :as => :user_session
      delete "logout" => "users/sessions#destroy", :as => :destroy_user_session
    end
  end

  # ===========================================================================
  # System administration

  namespace "admin" do
    get "/" => "dashboard#index", :as => :dashboard
    resources :catalogs, :param => :slug, :except => [:index, :destroy]
    resources :template_storages, :except => :index
    resources :configurations, :only => :update
    resources :users, :except => :index
  end

  mount Sidekiq::Web => "/sidekiq" # monitoring console
  root "home#index"

  # ===========================================================================
  # Catalog administration

  namespace "catalog_admin", :path => ":catalog_slug/admin" do
    get "/" => "dashboard#setup", :as => :setup
    get "/_data" => "dashboard#data", :as => :data

    resources :categories, :path => "_categories", :except => [:show] do
      resources :fields, :param => :slug, :except => :show
    end

    resources :item_types,
              :path => "_item-types",
              :only => [:new, :create]

    resources :item_types,
              :param => :slug,
              :path => "",
              :except => [:index, :show, :new, :create]

    resources :fields,
              :path => ":item_type_slug/fields",
              :param => :slug,
              :except => :show,
              :as => "item_type_fields"

    resources :csv_imports,
              :path => ":item_type_slug/import",
              :only => [:new, :create]

    resources :choice_sets, :path => "_choices", :except => :show do
      post 'create_choice' => 'choice_sets#create_choice'
    end

    resources :pages, :path => "_pages", :param => :slug do
      resources :containers,
                :path => "_containers",
                :shallow => true,
                :param => :id,
                :except => :show
    end
    resources :users, :path => "_users"
    resources :menu_items, path: '_menu_items'

    # Data entry
    resources :items, :path => ":item_type_slug", :except => :show do
      member do
        post "approval" => "approvals#create"
        delete "approval" => "approvals#destroy"
      end
    end
    post ":item_type_slug/upload" => "items#upload", :as => 'item_file_upload'
  end

  # ===========================================================================
  # Catalog viewing (public)

  get ":catalog_slug/(:locale)" => "catalogs#show",
      :as => "catalog_home",
      :constraints => CatalogsController::Constraint

  scope :path => ":catalog_slug/:locale",
        :constraints => CatalogsController::Constraint do
    get "search" => "simple_search#index", :as => "simple_search"

    resources :advanced_searches,
              :path => "search/advanced",
              :param => :uuid,
              :only => [:new, :create, :show]

    get ":slug" => "pages#show",
        :constraints => PagesController::Constraint,
        :as => :page

    resources :items,
              :path => ":item_type_slug",
              :only => [:index, :show],
              :constraints => ItemsController::Constraint

    get ":slug" => "custom#show", :constraints => CustomController::Constraint
  end

  # ===========================================================================
  # Image thumbnails

  get '/thumbs/:catalog_slug/:size/:mode/:field_uuid/:image.:ext',
    :to => 'images#thumbnail',
    :constraints => CatalogsController::Constraint

  # ===========================================================================
  # Error pages

  match '/404', to:'errors#error_404', :via => :all
  match '/422', to:'errors#error_404', :via => :all
  match '/500', to:'errors#error_500', :via => :all
  match '/505', to:'errors#error_500', :via => :all
end
