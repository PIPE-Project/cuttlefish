# frozen_string_literal: true

Formtastic::Helpers::FormHelper.builder = FormtasticBootstrap::FormBuilder

# Monkey patching this old version of formtastic so that it works with ruby 3.0
# We're stuck on this old version because the bootstrap-formtastic gem that still works
# with bootstrap 2 doesn't work with later formtastic. Ugh...
# I guess this is what you get when you're stuck on old versions of things.
module Formtastic
  module I18n
    class << self
      def translate(*args)
        key = args.shift.to_sym
        options = args.extract_options!
        options.reverse_merge!(:default => DEFAULT_VALUES[key])
        options[:scope] = [DEFAULT_SCOPE, options[:scope]].flatten.compact
        ::I18n.translate(key, *args, **options)
      end
      alias :t :translate
    end
  end
end

# Formtastic::Localizer#localize has a direct ::I18n.t(key, options_hash) call
# that bypasses the Formtastic::I18n patch above. In i18n >= 1.0, translate() only
# accepts keyword args after the key — a positional hash is a wrong number of args.
module Formtastic
  class Localizer
    def localize(key, value, type, options = {}) #:nodoc:
      key = value if value.is_a?(::Symbol)

      if value.is_a?(::String)
        escape_html_entities(value)
      else
        use_i18n = value.nil? ? i18n_lookups_by_default : (value != false)
        use_cache = i18n_cache_lookups
        cache = self.class.cache

        if use_i18n
          model_name, nested_model_name = normalize_model_name(builder.model_name.underscore)

          action_name = builder.template.params[:action].to_s rescue ''
          attribute_name = key.to_s

          if use_cache
            cache_key = [::I18n.locale, action_name, model_name, nested_model_name, attribute_name, key, value, type, options]
            return cache.get(cache_key) if cache.has_key?(cache_key)
          end

          defaults = Formtastic::I18n::SCOPES.reject do |i18n_scope|
            nested_model_name.nil? && i18n_scope.match(/nested_model/)
          end.collect do |i18n_scope|
            i18n_path = i18n_scope.dup
            i18n_path.gsub!('%{action}', action_name)
            i18n_path.gsub!('%{model}', model_name)
            i18n_path.gsub!('%{nested_model}', nested_model_name) unless nested_model_name.nil?
            i18n_path.gsub!('%{attribute}', attribute_name)
            i18n_path.gsub!('..', '.')
            i18n_path.to_sym
          end
          defaults << ''
          defaults.uniq!

          default_key = defaults.shift
          i18n_value = Formtastic::I18n.t(default_key,
            options.merge(:default => defaults, :scope => type.to_s.pluralize.to_sym))
          i18n_value = i18n_value.is_a?(::String) ? i18n_value : nil
          if i18n_value.blank? && type == :label
            options[:scope] = [:helpers, type]
            options[:default] = defaults
            i18n_value = ::I18n.t(default_key, **options)  # fixed: was positional hash
          end

          result = (i18n_value.is_a?(::String) && i18n_value.present?) ? escape_html_entities(i18n_value) : nil
          cache.set(cache_key, result) if use_cache
          result
        end
      end
    end
  end
end