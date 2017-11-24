require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    where_columns = params.keys.map { |attr_name| "#{attr_name} = ?"}.join(" AND ")
    where_values = params.values

    record_hashes = DBConnection.execute(<<-SQL, where_values)
      SELECT
        *
      FROM
        #{table_name} -- because of `extend`, `self` is the class object
      WHERE
        #{where_columns}
    SQL

    parse_all(record_hashes)

    # haskell_cats = Cat.where(:name => "Haskell", :color => "calico")
    # # SELECT
    # #   *
    # # FROM
    # #   cats
    # # WHERE
    # #   name = ? AND color = ?
    # I used a local variable where_line where I mapped the keys of the params to "#{key} = ?" and joined with AND.
    #
    # To fill in the question marks, I used the values of the params object.

  end
end

class SQLObject
  extend Searchable
end
