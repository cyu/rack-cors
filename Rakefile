  # encoding: utf-8

  require 'rubygems'
  require 'bundler'
  begin
    Bundler.setup(:default, :development)
   rescue Bundler::BundlerError => e
     $stderr.puts e.message
     $stderr.puts "Run `bundle install` to install missing gems"
     exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "rack-cors"
  gem.homepage = "http://github.com/cyu/rack-cors"
  gem.license = "MIT"
  gem.summary = "Middleware for enabling Cross-Origin Resource Sharing in Rack apps"
  gem.description = "Middleware that will make Rack-based apps CORS compatible.  Read more here: http://blog.sourcebender.com/2010/06/09/introducin-rack-cors.html.  Fork the project here: http://github.com/cyu/rack-cors"
  gem.email = "me@sourcebender.com"
  gem.authors = ["Calvin Yu"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "rack-cors2 #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

