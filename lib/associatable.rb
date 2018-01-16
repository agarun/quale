require_relative 'searchable'
require 'active_support/inflector'

class AssocOptions
  attr_accessor(
    :class_name,
    :foreign_key,
    :primary_key
  )

  def initialize(name, options = {})
    self.class_name = options[:class_name] ||
                      name.to_s.singularize.camelcase
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
    self.foreign_key = options[:foreign_key] ||
                       "#{name.to_s.underscore}_id".to_sym
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    super(name, options)
    self.foreign_key = options[:foreign_key] ||
                       "#{self_class_name.to_s.underscore}_id".to_sym
  end
end

module Associatable
  # Phase IIIb
  def belongs_to(name, options = {})
    data = BelongsToOptions.new(name, options)
    assoc_options[name] = data

    define_method(name) do
      # get the foreign key column on the current table
      foreign_key = data.foreign_key

      # get the value for the foreign key of the current record
      # (i.e. instance) from the current table
      foreign_key_value = self.send(foreign_key) #(foreign_key.to_sym)

      # get the target model class that this record belongs to
      model_class = data.model_class

      # link the primary key of the table this record belongs to (target table)
      # with this record's foreign key. return the associated object
      model_class.where(id: foreign_key_value).first
    end
  end

  def has_many(name, options = {})
    # pass in `self` as `self_class_name` because this association will
    # be associated with the current record's table
    data = HasManyOptions.new(name, self, options)

    define_method(name) do
      # link target table's foreign key with current table's primary key
      foreign_key = data.foreign_key

      # get current table's primary key
      primary_key = data.primary_key
      primary_key_value = self.send(primary_key)

      # find an array of results where target's foreign key matches current table's primary key
      model_class = data.model_class
      model_class.where(foreign_key => primary_key_value)
    end
  end

  # saves options for each association method
  def assoc_options
    @options ||= {}
  end

  # handle options inside so that inflector will constantize without error
  # inside `define_method`, `self` is the *instance*, outside it's the *class*
  def has_one_through(name, through_name, source_name)
    define_method(name) do
      through_options = self.class.assoc_options[through_name]
      source_options = through_options.model_class.assoc_options[source_name]

      through_table = through_options.table_name
      source_table = source_options.table_name

      through_p_k = through_options.primary_key
      source_p_k = source_options.primary_key

      through_f_k = through_options.foreign_key
      source_f_k = source_options.foreign_key

      record_hashes = DBConnection.execute(<<-SQL, self.owner_id)
        SELECT
          #{source_table}.*
        FROM
          #{through_table}
        JOIN
          #{source_table}
        ON
          #{through_table}.#{source_f_k} = #{source_table}.#{through_p_k}
        WHERE
          #{through_table}.#{through_p_k} = ?
      SQL

      source_options
        .model_class
        .parse_all(record_hashes)
        .first
    end
  end
end

# alternative `has_one_through` implementation
# def has_one_through(name, through_name, source_name)
#   define_method(name) do
#     through_options = self.class.assoc_options[through_name]
#     source_options = through_options.model_class.assoc_options[source_name]
#
#     through_f_k = self.send(through_options.foreign_key)
#     source_f_k = through_options
#       .model_class
#       .where(id: through_f_k)
#       .first
#       .send(source_options.foreign_key)
#
#     source_options
#       .model_class
#       .where(id: source_f_k)
#       .first
#   end
# end

# as an example, we are mimicking:
#
# class Cat < ApplicationRecord
#   has_one :home,
#     through: :human,
#     source: :house
# end
#
# ..trying to accomplish the following query in the cat model:
#
# SELECT
#   houses.*
# FROM
#   humans
# JOIN
#   houses ON humans.house_id = houses.id
# WHERE
#   humans.id = ?
