# frozen_string_literal: true

require_relative "mysql_rewinder/version"
require_relative "mysql_rewinder/cleaner"

module MysqlRewinder
  def self.init(db_configs, except_tables: [], adapter: :trilogy) # TODO: AR の管理系のやつ
    @cleaners = db_configs
      .map { |h| h.transform_keys(&:to_sym) }
      .group_by { |db_config| db_config.values_at(:host, :port, :username) }
      .values
      .map do |db_configs_in_group|
      Cleaner.new(
        db_configs_in_group.first.except(:database),
        databases: db_configs_in_group.map { |config| config[:database] }.compact.uniq,
        except_tables: except_tables,
        adapter: adapter
      )
    end
  end

  def self.clean_all
    @cleaners.each(&:clean_all)
  end

  def self.clean
    @cleaners.each(&:clean)
  end

  def self.cleaners
    @cleaners
  end
end
