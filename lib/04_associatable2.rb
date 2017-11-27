require_relative '03_associatable'

module Associatable
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
