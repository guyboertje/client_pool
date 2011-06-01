#! /usr/bin/env jruby

spec = Gem::Specification.new do |s|
  s.name = 'client_pool'
  s.version = '0.1.5'
  s.authors = ['Guy Boertje']
  s.email = 'gboertje@gowebtop.com'
  s.date = '2011-05-13'
  s.summary = 'A Pool for instance reuse'
  s.description = s.summary
  s.homepage = nil
  s.require_path = 'lib'
  s.files = ["Rakefile","README.rdoc", "LICENSE", "lib/client_pool.rb"]
  s.test_files = []
  s.has_rdoc = false
end
