# MysqlRewinder

MysqlRewinder is a simple, stable, and fast database cleaner for mysql.

It is heavily inspired by [database_rewinder](https://github.com/amatsuda/database_rewinder/tree/master).

## Features

* Fast cleanup using `DELETE` query
* Supports multi-database
* Supports both `mysql2` and `trilogy` as a client library
* Works without ActiveRecord
* Works with `fork`

## How does it work?

1. Capture SQL statements and extract `INSERT`ed table names, and record them into tmp files
2. Aggregate tmp files and execute DELETE query for `INSERT`ed tables

## What does `stable` mean?

MysqlRewinder is stable because it does not depend on ActiveRecord's internal implementation.
It only depends on `Mysql2::Client#query` and `Trilogy#query`.

## Installation

Add this line to your Gemfile's `:test` group:

```ruby
gem 'trilogy'
# gem 'mysql2' # described later
gem 'mysql_rewinder'
```

And then execute:

```shell
$ bundle
```

## Usage

### Basic configuration

```ruby
RSpec.configure do |config|
  config.before(:suite) do
    db_config = {
      host: '127.0.0.1',
      port: '3306',
      username: 'user1',
      password: 'my_secure_password',
      database: 'myapp-test'
    }
    MysqlRewinder.init([db_config])
    MysqlRewinder.clean_all
  end

  config.after(:each) do
    MysqlRewinder.clean
  end
end
```

### Multi-database

Pass all configurations to `MysqlRewinder.init`.

```ruby
MysqlRewinder.init(
  [
    { host: '127.0.0.1', port: '3306', username: 'user1', password: 'my_secure_password', database: 'myapp-test-shard1' },
    { host: '127.0.0.1', port: '3306', username: 'user1', password: 'my_secure_password', database: 'myapp-test-shard2' },
  ]
)
```

### mysql2

If you want to use `mysql2` as a client library, do the following:

* Write `gem 'mysql2'` in your `Gemfile`
* Pass `adapter: :mysql2` to `MysqlRewinder.init`.

```ruby
MysqlRewinder.init(db_configs, adapter: :mysql2)
```

### ActiveRecord

If you want to use MysqlRewinder with ActiveRecord, do the following:

* Generate db_configs from `ActiveRecord::Base.configurations`
* Pass `ActiveRecord::SchemaMigration.new(nil).table_name` and `ActiveRecord::Base.internal_metadata_table_name` to `DatabaseRewinder.init` as `except_tables`

```ruby
db_configs = ActiveRecord::Base.configurations.configs_for(env_name: 'test').map(&:configuration_hash)
except_tables = [
  ActiveRecord::Base.internal_metadata_table_name,

  # for AR >= 7.1
  ActiveRecord::SchemaMigration.new(nil).table_name,
  # for AR < 7.1
  # ActiveRecord::SchemaMigration.table_name,
]

MysqlRewinder.init(db_configs, except_tables: except_tables)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/genya0407/mysql_rewinder.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
