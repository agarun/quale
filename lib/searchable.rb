require_relative 'connection'

module Searchable
  def where(params)
    where_columns = params
      .keys
      .map { |attr_name| "#{attr_name} = ?" }
      .join(" AND ")
    where_values = params.values

    # because of `extend`, `self` is the class object
    record_hashes = DBConnection.execute(<<-SQL, where_values)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        #{where_columns}
    SQL

    parse_all(record_hashes)
  end
end
