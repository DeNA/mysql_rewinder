require_relative 'cleaner/adapter'
require_relative 'cleaner/mysql2_adapter'
require_relative 'cleaner/trilogy_adapter'

class MysqlRewinder
  class Cleaner
    attr_reader :db_config

    def initialize(db_config, except_tables:, adapter:)
      @db_config = db_config
      @client = Adapter.generate(adapter, db_config.transform_keys(&:to_sym))
      @except_tables = except_tables
    end

    def clean_all
      clean(tables: all_tables)
    end

    def clean(tables:)
      target_tables = (tables - @except_tables) & all_tables
      return if target_tables.empty?

      @client.execute(target_tables.map { |table| "DELETE FROM #{table}" }.join(';'))
    end

    def all_tables
      @all_tables ||= @client.query(<<~SQL).flatten
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
      SQL
    end
  end
end
