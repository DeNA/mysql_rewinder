RSpec.describe MysqlRewinder do
  %i[mysql2 trilogy].each do |adapter|
    describe "adapter: #{adapter}" do
      let(:root_db_config) { { host: '127.0.0.1', port: '3306', username: 'root', database: 'mysql' } }
      let(:client_class) { { mysql2: Mysql2::Client, trilogy: Trilogy }[adapter] }

      def root_client
        client_class.new(root_db_config)
      end

      context 'when initialized with multiple configs' do
        let(:db_configs) do
          [
            { host: '127.0.0.1', port: '3306', username: 'database_rewinder_test_user1', database: 'database_rewinder_test_a' },
            { host: '127.0.0.1', port: '3306', username: 'database_rewinder_test_user2', database: 'database_rewinder_test_b' },
            { host: '127.0.0.1', port: '3306', username: 'database_rewinder_test_user2', database: 'database_rewinder_test_c' }
          ]
        end

        before do
          %w[a b c].each do |suffix|
            <<~SQL.split(';').map(&:strip).reject(&:empty?).each { |sql| root_client.query(sql) }
              DROP DATABASE IF EXISTS database_rewinder_test_#{suffix};
              CREATE DATABASE database_rewinder_test_#{suffix};
              CREATE TABLE database_rewinder_test_#{suffix}.hoge (
                id INT NOT NULL AUTO_INCREMENT,
                price INT NOT NULL,
                PRIMARY KEY (id)
              );
            SQL
          end
          %w[1 2].each do |suffix|
            <<~SQL.split(';').map(&:strip).reject(&:empty?).each { |sql| root_client.query(sql) }
              DROP USER IF EXISTS database_rewinder_test_user#{suffix};
              CREATE USER database_rewinder_test_user#{suffix};
            SQL
          end
          <<~SQL.split(';').map(&:strip).reject(&:empty?).each { |sql| root_client.query(sql) }
            GRANT ALL ON database_rewinder_test_a.* TO database_rewinder_test_user1;
            GRANT ALL ON database_rewinder_test_b.* TO database_rewinder_test_user2;
            GRANT ALL ON database_rewinder_test_c.* TO database_rewinder_test_user2;
          SQL

          MysqlRewinder.setup(db_configs, adapter: adapter, except_tables: [])

          <<~SQL.split(';').map(&:strip).reject(&:empty?).each { |sql| root_client.query(sql) }
            INSERT INTO database_rewinder_test_a.hoge (price) VALUES (108);
            INSERT INTO database_rewinder_test_b.hoge (price) VALUES (108);
            INSERT INTO database_rewinder_test_c.hoge (price) VALUES (108);
          SQL
        end

        it 'removes records using appropriate config' do
          expect { MysqlRewinder.clean }.to change {
            [
              root_client.query('SELECT * FROM database_rewinder_test_a.hoge').to_a.size,
              root_client.query('SELECT * FROM database_rewinder_test_b.hoge').to_a.size,
              root_client.query('SELECT * FROM database_rewinder_test_b.hoge').to_a.size,
            ]
          }.from([1,1,1]).to([0,0,0])
        end
      end

      context 'when record inserted before and after initialized' do
        before do
          <<~SQL.split(';').map(&:strip).reject(&:empty?).each { |sql| root_client.query(sql) }
            DROP DATABASE IF EXISTS database_rewinder_test;
            CREATE DATABASE database_rewinder_test;
            CREATE TABLE database_rewinder_test.foo (
                id INT NOT NULL AUTO_INCREMENT,
                name VARCHAR(128) NOT NULL,
                PRIMARY KEY (id)
            );
            CREATE TABLE database_rewinder_test.bar (
                id INT NOT NULL AUTO_INCREMENT,
                age INT NOT NULL,
                PRIMARY KEY (id)
            );
            CREATE TABLE database_rewinder_test.piyo (
                id INT NOT NULL AUTO_INCREMENT,
                name VARCHAR(128) NOT NULL,
                PRIMARY KEY (id)
            ) PARTITION BY HASH( id ) PARTITIONS 6;
            CREATE TABLE database_rewinder_test.hohho (
                id INT NOT NULL AUTO_INCREMENT,
                name VARCHAR(128) NOT NULL,
                PRIMARY KEY (id)
            );
    
            DROP DATABASE IF EXISTS database_rewinder_test_2;
            CREATE DATABASE database_rewinder_test_2;
            CREATE TABLE database_rewinder_test_2.foo_2 (
                id INT NOT NULL AUTO_INCREMENT,
                name VARCHAR(128) NOT NULL,
                PRIMARY KEY (id)
            );
          SQL

          root_client.query(<<~SQL)
            INSERT INTO database_rewinder_test.foo (name) VALUES ("hitori")
          SQL

          MysqlRewinder.setup([root_db_config.merge(database: 'database_rewinder_test')], adapter: adapter, except_tables: [])

          root_client.query(<<~SQL)
            INSERT INTO database_rewinder_test.bar (age) VALUES (15)
          SQL

          root_client.query(<<~SQL)
            INSERT INTO database_rewinder_test.piyo (name) VALUES ("nijika")
          SQL

          root_client.query(<<~SQL)
            INSERT INTO database_rewinder_test_2.foo_2 (name) VALUES ("nijika")
          SQL

          pid = fork do
            client_class.new(root_db_config).query(<<~SQL)
            INSERT INTO database_rewinder_test.hohho (name) VALUES ("ryo")
            SQL
          end
          Process.waitpid(pid)
        end

        it 'removes records inserted after init' do
          expect { MysqlRewinder.clean }.to change {
            root_client.query('SELECT * FROM database_rewinder_test.bar').to_a.size
          }.from(1).to(0)
        end

        it 'does not remove records inserted before init' do
          expect { MysqlRewinder.clean }.not_to change {
            root_client.query('SELECT * FROM database_rewinder_test.foo').to_a.size
          }.from(1)
        end

        it 'removes records in partitioned table' do
          expect { MysqlRewinder.clean }.to change {
            root_client.query('SELECT * FROM database_rewinder_test.piyo').to_a.size
          }.from(1).to(0)
        end


        it 'removes records inserted in child process' do
          expect { MysqlRewinder.clean }.to change {
            root_client.query('SELECT * FROM database_rewinder_test.hohho').to_a.size
          }.from(1).to(0)
        end

        it 'does not remove records in other database' do
          expect { MysqlRewinder.clean }.not_to change {
            root_client.query('SELECT * FROM database_rewinder_test_2.foo_2').to_a.size
          }.from(1)
        end
      end
    end
  end
end
