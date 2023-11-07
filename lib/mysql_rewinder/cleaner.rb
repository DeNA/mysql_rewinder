class MysqlRewinder
  class Cleaner
    attr_reader :db_config

    def initialize(db_config, except_tables:, adapter:)
      @db_config = db_config
      @client = self.class.client_class(adapter).new(db_config.transform_keys(&:to_sym))
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

    def self.client_class(adapter)
      case adapter
      when :trilogy
        trilogy_client
      when :mysql2
        mysql2_client
      else
        raise 'adapter must be either :trilogy or :mysql2'
      end
    end

    def self.trilogy_client
      require 'trilogy'
      require_relative 'ext/trilogy'

      TrilogyAdapter
    end

    def self.mysql2_client
      require 'mysql2'
      require_relative 'ext/mysql2_client'

      Mysql2Adapter
    end

    class TrilogyAdapter
      def initialize(db_config)
        @db_config = db_config
        connect
      end

      def query(sql)
        with_reconnect do
          @client.query(sql).to_a
        end
      end

      def execute(sql)
        with_reconnect do
          @client.query(sql)
          @client.next_result while @client.more_results_exist?
        end
      end

      private
      def with_reconnect(&block)
        retry_count = 0
        begin
          block.call
        rescue Trilogy::Error => e
          raise e if retry_count > 3

          connect
          retry_count += 1

          retry
        end
      end

      def connect
        @client&.close
        @client = Trilogy.new(@db_config.merge(multi_statement: true))
      end
    end

    class Mysql2Adapter
      def initialize(db_config)
        @db_config = db_config
        connect
      end

      def query(sql)
        with_reconnect do
          @client.query(sql, as: :array).to_a
        end
      end

      def execute(sql)
        with_reconnect do
          @client.query(sql)
          @client.store_result while @client.next_result
        end
      end

      private
      def with_reconnect(&block)
        retry_count = 0
        begin
          block.call
        rescue Mysql2::Error => e
          raise e if retry_count > 3

          connect
          retry_count += 1

          retry
        end
      end

      def connect
        @client&.close
        @client = Mysql2::Client.new(@db_config.merge(connect_flags: Mysql2::Client::MULTI_STATEMENTS))
      end
    end
  end
end
