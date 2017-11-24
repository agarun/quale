require_relative 'db_connection'
require 'active_support/inflector'
# TODO: remove this comment:
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

# #insert: insert a new row into the table to represent the SQLObject.
# #update: update the row with the id of this SQLObject
# #save: convenience method that either calls insert/update depending on whether or not the SQLObject already exists in the table.

class SQLObject
  def self.columns
    # the first element in `execute2` output is an array of column name strings
    @columns ||=
      DBConnection.execute2(<<-SQL)
        SELECT
          *
        FROM
          #{table_name}
      SQL
      .first
      .map(&:to_sym)
  end

  # automatically adds getter and setter methods for each column because
  # intended to be used on `self` at the end of subclass definitions
  def self.finalize!
    columns.each do |column|
      define_method("#{column}") { attributes[column] }
      define_method("#{column}=") { |value| attributes[column] = value }
    end
  end

  # override the table name in cases where `ActiveSupport::Inflector` infers incorrectly
  def self.table_name=(table_name)
    @table_name = table_name
  end

  # get the name of the table for the class
  # using `String#tableize` from ActiveSupport::Inflector
  def self.table_name
    @table_name || "#{self}".tableize
  end

  # fetch `all` the records from the database (name derived from `::table_name`)
  def self.all
    record_hashes = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
    SQL

    parse_all(record_hashes)
  end

  # helper method to map record hashes to record objects (i.e. Relation objects)
  def self.parse_all(results)
    results.map { |record_hash| self.new(record_hash) }
  end

  # return a single object with the given 'id' (primary key)
  # note `DBConnection.execute` returns an array even if there is one result
  def self.find(id)
    record = DBConnection.execute(<<-SQL, id: id)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        id = :id
    SQL

    record.empty? ? nil : self.new(record.first)
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      raise "unknown attribute '#{attr_name}'" unless self.class.columns.include?(attr_name.to_sym)

      send("#{attr_name.to_sym}=", value) # setter defined in `::finalize!`
    end
  end

  def attributes
    @attributes ||= {}
  end

  # NOTE: cannot simply use `#attributes.values` because it
  # will not include `nil` values (e.g. when there is no `id` yet)
  def attribute_values
    self.class.columns.map { |x| send(x) }
  end

  # FIXME: `#insert` and `#update` should be private methods
  # insert new record (self) and initialize the record's primary key
  def insert
    column_names = self.class.columns.join(", ") # => "col1, col2, col3, ..."
    question_marks = (["?"] * self.class.columns.size).join(", ") # => "?, ?, ?, ..."

    DBConnection.execute(<<-SQL, attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{column_names})
      VALUES
        (#{question_marks})
    SQL

    send(:id=, DBConnection.last_insert_row_id)
  end

  def update
    set_columns = self.class.columns.map { |attr_name| "#{attr_name} = ?"}.join(", ")

    DBConnection.execute(<<-SQL, attribute_values, id: attributes[:id])
      UPDATE
        #{self.class.table_name}
      SET
        #{set_columns}
      WHERE
        id = :id
    SQL
  end

  def save
    id.nil? ? insert : update
  end
end
