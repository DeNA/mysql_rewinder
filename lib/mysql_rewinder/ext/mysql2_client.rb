require 'mysql2'

class MysqlRewinder
  module Ext
    module Mysql2Client
      def query(sql, _options = {})
        MysqlRewinder.record_inserted_table(sql)

        super
      end
    end
  end
end
::Mysql2::Client.prepend ::MysqlRewinder::Ext::Mysql2Client
