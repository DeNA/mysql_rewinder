class MysqlRewinder
  class Cleaner
    class TrilogyAdapter < Adapter
      def initialize(db_config)
        super
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
  end
end