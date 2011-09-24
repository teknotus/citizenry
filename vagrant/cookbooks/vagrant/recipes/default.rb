APPDIR = "/vagrant" # Application directory
USER = "vagrant"      # User that owns files

# Change directory to /vagrant after doing a `vagrant ssh`.
execute "update-profile-chdir" do
  profile = "~vagrant/.profile"
  command %{printf "\nif shopt -q login_shell; then cd #{APPDIR}; fi" >> #{profile}}
  not_if "grep -q 'cd #{APPDIR}' #{profile}"
end

# Update package list, but only if stale
execute "update-apt" do
  timestamp = "/root/.apt-get-updated"
  command "apt-get update && touch #{timestamp}"
  only_if do
    ! File.exist?(timestamp) || (File.stat(timestamp).mtime + 60*60) < Time.now
  end
end

# Add gems to PATH
file "/etc/profile.d/rubygems1.8.sh" do
  content "PATH=/usr/lib/ruby/gems/1.8/bin:$PATH"
end

# Install packages
for name in %w[nfs-common git-core screen tmux elinks build-essential ruby-dev irb libcurl4-openssl-dev libsqlite3-dev mysql-server libmysqlclient-dev libxml2 libxml2-dev libxslt1.1 libxslt1-dev sphinxsearch imagemagick]
  package name
end

# Install gems
for name in %w[bundler]
  gem_package name
end

# Run the contents of the "vagrant/cookbooks/vagrant/recipes/local.rb" file if present. This optional file can contain additional provisioning logic that shouldn't be part of the global setup. For example, if you're using the "Gemfile.local" to install special gems, you'd use this "local.rb" to install their dependencies.
local_recipe = File.join(File.dirname(__FILE__), "local.rb")
if File.exist?(local_recipe)
  eval File.read(local_recipe)
end

# Copy in sample YML files, if needed:
for name in %w[settings database]
  source = "#{APPDIR}/config/#{name}-sample.yml"
  target = "#{APPDIR}/config/#{name}.yml"

  execute "cp -a #{source} #{target}" do
    not_if "test -e #{target}"
  end
end

# Fix permissions on homedir
execute "chown -R #{USER}:#{USER} ~#{USER}"

# Install bundle
execute "install-bundle" do
  cwd APPDIR
  command "su #{USER} -c 'bundle check || bundle --local || bundle'"
end

# Setup database
execute "setup-db" do
  cwd APPDIR
  command "su #{USER} -c 'bundle exec rake db:create:all db:migrate db:test:prepare'"
end
