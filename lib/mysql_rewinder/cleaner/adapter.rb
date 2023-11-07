class MysqlRewinder
  class Cleaner
    class Adapter
      def self.generate(adapter, config)
        case adapter
        when :trilogy
          require 'trilogy'
          require_relative '../ext/trilogy'

          TrilogyAdapter.new(config)
        when :mysql2
          require 'mysql2'
          require_relative '../ext/mysql2_client'

          Mysql2Adapter.new(config)
        else
          raise 'adapter must be either :trilogy or :mysql2'
        end
      end

      def initialize(_config); end

      def query(sql)
        raise NotImplementedError
      end

      def execute(sql)
        raise NotImplementedError
      end
    end
  end
end
