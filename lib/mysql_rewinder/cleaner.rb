module MysqlRewinder
  class Cleaner
    attr_reader :databases, :db_config

    def initialize(db_config, databases:, except_tables:, adapter:)
      raise ArgumentError, 'databases cannot be empty' if databases.empty?

      @db_config = db_config
      @client = self.class
                    .client_class(adapter)
                    .new(db_config.transform_keys(&:to_sym))
                    .tap do |c|
        unless c.query("SHOW VARIABLES LIKE 'information_schema_stats_expiry'").to_a.empty? # For MySQL 5.7 compatibility
          c.execute('SET information_schema_stats_expiry = 0')
        end
      end
      @databases = databases
      @except_tables = except_tables
      @delete_after = @client.query("SELECT CURRENT_TIMESTAMP()").first.first
    end

    def clean_all
      delete_tables(tables: all_tables)
    end

    def clean
      # UPDATE_TIME in INFORMATION_SCHEMA.TABLES is not updated if it is partitioned.
      # So we also use UPDATE_TIME in INFORMATION_SCHEMA.PARTITIONS.
      tables = @client.query(<<~SQL).map { |db_name, table_name| "#{db_name}.#{table_name}" }
        SELECT TABLE_SCHEMA, TABLE_NAME
          FROM INFORMATION_SCHEMA.TABLES
          WHERE TABLE_SCHEMA IN (#{@databases.map { |d| '"' + d + '"'}.join(',')})
          AND UPDATE_TIME >= "#{@delete_after.strftime('%Y-%m-%d %H:%M:%S')}"

        UNION

        (SELECT TABLE_SCHEMA, TABLE_NAME
          FROM INFORMATION_SCHEMA.PARTITIONS
          WHERE TABLE_SCHEMA IN (#{@databases.map { |d| '"' + d + '"'}.join(',')})
          AND UPDATE_TIME >= "#{@delete_after.strftime('%Y-%m-%d %H:%M:%S')}")
      SQL
      delete_tables(tables: tables)
    end

    def delete_tables(tables:)
      return if tables.empty?

      @client.execute(tables.map { |table| "DELETE FROM #{table}" }.join(';'))
      @delete_after = @client.query("SELECT CURRENT_TIME()").first.first
    end

    def all_tables
      @all_tables ||= @client.query(<<~SQL).map { |db_name, table_name| "#{db_name}.#{table_name}" }
        SELECT TABLE_SCHEMA, TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA IN (#{@databases.map { |d| '"' + d + '"'}})
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

      TrilogyAdapter
    end

    def self.mysql2_client
      require 'mysql2'

      Mysql2Adapter
    end

    class TrilogyAdapter
      def initialize(db_config)
        @client = Trilogy.new(db_config.merge(multi_statement: true))
      end

      def query(sql)
        @client.query(sql).to_a
      end

      def execute(sql)
        @client.query(sql)
        @client.next_result while @client.more_results_exist?
      end
    end

    class Mysql2Adapter
      def initialize(db_config)
        @client = Mysql2::Client.new(db_config.merge(connect_flags: Mysql2::Client::MULTI_STATEMENTS))
      end

      def query(sql)
        @client.query(sql, as: :array).to_a
      end

      def execute(sql)
        @client.query(sql)
        @client.store_result while @client.next_result
      end
    end
  end
end
