require 'trilogy'

module MysqlRewinder
  module Ext
    module Trilogy
      def query(sql)
        MysqlRewinder.record_inserted_table(sql)

        super
      end
    end
  end
end
::Trilogy.prepend ::MysqlRewinder::Ext::Trilogy
