# The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
# config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
Rails.application.config.i18n.default_locale = :en
Rails.application.config.i18n.available_locales = %i(de en fr it)

# TODO: uncomment once Catalog behavior is implemented
# I18n::Backend::Simple.include(I18n::Backend::Fallbacks)
# I18n.fallbacks = Catalog::I18nFallbacks.new