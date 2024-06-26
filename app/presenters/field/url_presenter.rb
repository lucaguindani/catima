class Field::URLPresenter < FieldPresenter
  include ActionView::Helpers
  include LocaleHelper

  def input(form, method, options={})
    i18n = options.fetch(:i18n) { field.i18n? }
    return i18n_input(form, method, options) if i18n

    form.url_field(method, input_defaults(options).merge(help: help))
  end

  def i18n_input(form, method, options={})
    locale_form_group(
      form,
      method,
      :url_field,
      input_defaults(options).merge(help: help)
    )
  end

  def value
    return if raw_value.blank?

    compact = raw_value[%r{^https?://(.+?)/?$}, 1] || raw_value
    link_to(compact, raw_value, :target => "_blank", rel: "noopener")
  end
end
