namespace :gem do

  desc "Install the gem locally"
  task :install do
    sh "gem build client_pool.gemspec"
    sh "gem install client_pool-*.gem"
    sh "rm client_pool-*.gem"
  end

end
