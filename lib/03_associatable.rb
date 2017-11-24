require_relative '02_searchable'
require 'active_support/inflector'

# Phase IIIa
class AssocOptions
  attr_accessor(
    :class_name,
    :foreign_key,
    :primary_key
  )

  def initialize(name, options = {})
    self.class_name = options[:class_name] || "#{name.to_s.singularize.camelcase}"
    self.primary_key = options[:primary_key] || :id
  end

  def model_class
    class_name.constantize
  end

  def table_name
    model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    super(name, options)
    self.foreign_key = options[:foreign_key] || "#{name.to_s.underscore}_id".to_sym
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    super(name, options)
    self.foreign_key = options[:foreign_key] || "#{self_class_name.to_s.underscore}_id".to_sym
  end
end

# Begin writing a belongs_to method for Associatable. This method should take in the association name and an options hash. It should build a BelongsToOptions object; save this in a local variable named options.
#
# Within belongs_to, call define_method to create a new method to access the association. Within this method:
#
# Use send to get the value of the foreign key.
# Use model_class to get the target model class.
# Use where to select those models where the primary_key column is equal to the foreign key value.
# Call first (since there should be only one such item).
# Throughout this method definition, use the options object so that defaults are used appropriately.

# Do likewise for has_many.

module Associatable
  # Phase IIIb
  def belongs_to(name, options = {})
    data = BelongsToOptions.new(name, options)

    define_method(name) do
      # get the foreign key column on the current table
      foreign_key = data.foreign_key

      # get the value for the foreign key of the current record
      # (i.e. instance) from the current table
      foreign_key_value = self.send(foreign_key.to_sym)

      # get the target model class that this record belongs to
      model_class = data.model_class

      # link the primary key of the table this record belongs to
      # with this record's foreign key
      model_class.where(id: foreign_key_value).first
    end
  end

  def has_many(name, options = {})
    data = HasManyOptions.new(name, options)

    define_method(name) do

    end
  end

  def assoc_options
    # Wait to implement this in Phase IVa. Modify `belongs_to`, too.
  end
end

class SQLObject
  # Mixin Associatable here...
  extend Associatable
end
