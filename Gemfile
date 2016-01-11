source "https://rubygems.org"

abort 'Ruby should be >= 2.0.0' unless RUBY_VERSION.to_f >= 2.0

gem 'json'
gem 'nokogiri'
gem 'pry'
gem 'rake'
gem 'csv_to_popolo', '~> 0.18.1', :github => 'tmtmtmtm/csv_to_popolo'
gem 'colorize'
gem 'fuzzy_match'
gem 'iso_country_codes'
gem 'yajl-ruby', require: 'yajl'
gem 'sass'
gem 'unicode_utils'
gem 'wikisnakker', git: 'https://github.com/everypolitician/wikisnakker', branch: 'master'
gem 'everypolitician-popolo', git: 'https://github.com/everypolitician/everypolitician-popolo', branch: 'master'

group :test do
  gem 'minitest'
  gem 'minitest-around'
  gem 'vcr'
  gem 'webmock'
end
