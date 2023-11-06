# frozen_string_literal: true

require_relative "mysql_rewinder/version"
require_relative "mysql_rewinder/cleaner"
require 'set'
require 'tmpdir'
require 'fileutils'

module MysqlRewinder
  def self.init(db_configs, except_tables: [], adapter: :trilogy)
    @initialized_pid = Process.pid
    @inserted_table_record_dir = Pathname(Dir.tmpdir)
    @cleaners = db_configs.map do |db_config|
      Cleaner.new(
        db_config.transform_keys(&:to_sym),
        except_tables: except_tables,
        adapter: adapter
      )
    end
    reset_inserted_tables
  end

  def self.record_inserted_table(sql)
    return unless @initialized_pid

    @inserted_tables ||= Set.new
    sql.split(';').each do |statement|
      match = statement.match(/\A\s*INSERT(?:\s+IGNORE)?(?:\s+INTO)?\s+(?:\.*[`"]?([^.\s`"(]+)[`"]?)*/i)
      next unless match

      table = match[1]
      @inserted_tables << table if table
    end
    File.write(
      @inserted_table_record_dir.join("#{@initialized_pid}.#{Process.pid}.inserted_tables"),
      @inserted_tables.join(',')
    )
  end

  def self.reset_inserted_tables
    unless @initialized_pid == Process.pid
      raise "MysqlRewinder is initialize in process #{@initialized_pid}, but reset_inserted_tables is called in process #{Process.pid}"
    end

    @inserted_tables = Set.new
    FileUtils.rm(Dir.glob(@inserted_table_record_dir.join("#{@initialized_pid}.*.inserted_tables").to_s))
  end

  def self.calculate_inserted_tables
    unless @initialized_pid == Process.pid
      raise "MysqlRewinder is initialize in process #{@initialized_pid}, but calculate_inserted_tables is called in process #{Process.pid}"
    end

    Dir.glob(@inserted_table_record_dir.join("#{@initialized_pid}.*.inserted_tables").to_s).flat_map do |fname|
      File.read(fname).strip.split(',')
    end.uniq
  end

  def self.clean_all
    cleaners.each(&:clean_all)
    reset_inserted_tables
  end

  def self.clean
    aggregated_inserted_tables = calculate_inserted_tables
    cleaners.each { |c| c.clean(tables: aggregated_inserted_tables) }
    reset_inserted_tables
  end

  def self.cleaners
    @cleaners
  end
end
