#! /usr/bin/env jruby

spec = Gem::Specification.new do |s|
  s.name = 'client_pool'
  s.version = '0.1.7'
  s.authors = ['Guy Boertje']
  s.email = 'gboertje@gowebtop.com'
  s.date = '2011-05-13'
  s.summary = 'A Pool for instance reuse'
  s.description = s.summary
  s.homepage = nil
  s.require_path = 'lib'
  s.files = %W[Rakefile README.rdoc LICENSE lib/client_pool.rb spec/spec_helper.rb spec/client_pool_spec.rb]
  s.test_files = []
end
