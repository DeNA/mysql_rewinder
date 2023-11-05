# frozen_string_literal: true

require_relative "lib/mysql_rewinder/version"

Gem::Specification.new do |spec|
  spec.name = "mysql_rewinder"
  spec.version = MysqlRewinder::VERSION
  spec.authors = ["Yusuke Sangenya"]
  spec.email = ["longinus.eva@gmail.com"]

  spec.summary = "Simple, stable, and fast database cleaner for mysql"
  spec.homepage = "https://github.com/genya0407/mysql_rewinder"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.require_paths = ["lib"]
end
