class CatalogAdmin::ChoiceSetsController < CatalogAdmin::BaseController
  layout "catalog_admin/setup/form"

  def index
    authorize(ChoiceSet)
    @choice_sets = catalog.choice_sets.sorted
    render("index", :layout => "catalog_admin/setup")
  end

  def new
    build_choice_set
    authorize(@choice_set)
  end

  def create
    build_choice_set
    authorize(@choice_set)
    @choice_set.attributes = choice_set_params
    apply_choice_set_to_choices

    if @choice_set.save
      redirect_to(after_create_path, :notice => created_message)
    else
      logger.debug(@choice_set.errors.inspect)
      render("new")
    end
  end

  # def edit
  #   find_choice_set
  #   authorize(@choice_set)
  # end

  # def update
  #   find_choice_set
  #   authorize(@choice_set)
  #   if @choice_set.update(choice_set_params)
  #     redirect_to(catalog_admin_choice_sets_path, :notice => updated_message)
  #   else
  #     render("edit")
  #   end
  # end

  private

  def build_choice_set
    @choice_set = catalog.choice_sets.new
  end

  # def find_choice_set
  #   @choice_set = ChoiceSet.find(params[:id])
  # end

  def choice_set_params
    params.require(:choice_set).permit(
      :name,
      :choices_attributes => [
        :id, :_destroy,
        :short_name_de, :short_name_en, :short_name_fr, :short_name_it,
        :long_name_de, :long_name_en, :long_name_fr, :long_name_it
      ])
  end

  def apply_choice_set_to_choices
    @choice_set.choices.each { |c| c.choice_set = @choice_set }
  end

  def created_message
    "Choice set “#{@choice_set.name}” has been created."
  end

  def after_create_path
    case params[:commit]
    when /another/i then new_catalog_admin_choice_set_path
    else catalog_admin_choice_sets_path(catalog, @item_type)
    end
  end
  # def choice_set_updated_message
  #   "#{@choice_set.email} has been saved."
  # end
end