# MysqlRewinder ![test](https://github.com/github/docs/actions/workflows/test.yml/badge.svg) [![Gem Version](https://badge.fury.io/rb/mysql_rewinder.svg)](https://badge.fury.io/rb/mysql_rewinder)

MysqlRewinder is a simple, stable, and fast database cleaner for mysql.

## Features

* Fast cleanup using `DELETE` query
* Supports multi-database
* Supports both `mysql2` and `trilogy` as a client library
* Works without ActiveRecord
* Works with `fork`

## How does it work?

1. Capture SQL statements during test execution and extract `INSERT`ed table names, and record them into temporary files
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
    MysqlRewinder.setup([db_config])
    MysqlRewinder.clean_all
  end

  config.after(:each) do
    MysqlRewinder.clean
  end
end
```

### Multi-database

Pass all configurations to `MysqlRewinder.setup`.

```ruby
MysqlRewinder.setup(
  [
    { host: '127.0.0.1', port: '3306', username: 'user1', password: 'my_secure_password', database: 'myapp-test-shard1' },
    { host: '127.0.0.1', port: '3306', username: 'user1', password: 'my_secure_password', database: 'myapp-test-shard2' },
  ]
)
```

### mysql2

If you want to use `mysql2` as a client library, do the following:

* Write `gem 'mysql2'` in your `Gemfile`
* Pass `adapter: :mysql2` to `MysqlRewinder.setup`.

```ruby
MysqlRewinder.setup(db_configs, adapter: :mysql2)
```

### ActiveRecord

If you want to use MysqlRewinder with ActiveRecord, do the following:

* Generate db_configs from `ActiveRecord::Base.configurations`
* Pass `ActiveRecord::SchemaMigration.new(nil).table_name` and `ActiveRecord::Base.internal_metadata_table_name` to `DatabaseRewinder.setup` as `except_tables`

```ruby
db_configs = ActiveRecord::Base.configurations.configs_for(env_name: 'test').map(&:configuration_hash)
except_tables = [
  ActiveRecord::Base.internal_metadata_table_name,

  # for AR >= 7.1
  ActiveRecord::SchemaMigration.new(nil).table_name,
  # for AR < 7.1
  # ActiveRecord::SchemaMigration.table_name,
]

MysqlRewinder.setup(db_configs, except_tables: except_tables)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/DeNA/mysql_rewinder. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/DeNA/mysql_rewinder/blob/trunk/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the MysqlRewinder project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/DeNA/mysql_rewinder/blob/trunk/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Special Thanks

* Thank you [@aeroastro](https://github.com/aeroastro) for the idea of using temporary files
* This gem is heavily inspired by [amatsuda/database_rewinder](https://github.com/amatsuda/database_rewinder).
