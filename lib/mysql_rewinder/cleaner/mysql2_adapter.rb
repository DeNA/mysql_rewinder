class MysqlRewinder
  class Cleaner
    class Mysql2Adapter < Adapter
      def initialize(db_config)
        super
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