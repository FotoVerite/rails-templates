 
# Delete unnecessary files
run "echo TODO > README"
run "rm doc/README_FOR_APP"
run "rm public/index.html"
run "rm public/favicon.ico"
run "rm public/robots.txt"
 
# Set up git repository
git :init
 
# Copy database.yml for distribution use
run "cp config/database.yml config/database.yml.example"
 
# Set up .gitignore files
run %{find . -type d -empty | xargs -I xxx touch xxx/.gitignore}
file '.gitignore', <<-END
.DS_Store
coverage/*
log/*.log
db/*.db
db/schema.rb
tmp/**/*
config/database.yml
coverage/*
END

# Download JQuery
run "curl -L http://jqueryjs.googlecode.com/files/jquery-1.2.6.min.js > public/javascripts/jquery.js"
run "curl -L http://jqueryjs.googlecode.com/svn/trunk/plugins/form/jquery.form.js > public/javascripts/jquery.form.js"
 
# Install plugins as git submodules
plugin 'restful_authenticate', :git =>'git://github.com/technoweenie/restful-authentication.git', :submodule => true
plugin 'rspec', :git => 'git://github.com/dchelimsky/rspec.git', :submodule => true
plugin 'rspec-rails', :git => 'git://github.com/dchelimsky/rspec-rails.git', :submodule => true
plugin 'asset_packager', :git => 'git://github.com/sbecker/asset_packager.git', :submodule => true
plugin 'rr', :git => 'git://github.com/btakita/rr.git', :submodule => true
plugin 'will_paginate', :git => 'git://github.com/mislav/will_paginate.git', :submodule => true
plugin 'webrat', :git => 'git://github.com/brynary/webrat.git', :submodule => true
plugin 'cucumber', :git => 'git://github.com/aslakhellesoy/cucumber.git vendor/plugins/cucumber', :submodule => true

#gems
gem 'nokogiri'
rake "gems:install", :sudo => true

# welcome-route
route "map.root :controller => 'main'"
route "map.welcome :controller => 'main'"
route 'map.resource :user_session'


# Initialize submodules
git :submodule => "init"
  
# Set up sessions, RSpec, user model, OpenID, etc, and run migrations
generate :rspec
generate :cucumber
generate 'restful_authenticate --stateful'
 
# Commit all work so far to the repository
git :add => '.'
git :commit => "-a -m 'Initial commit'"
 
# Success!
puts "SUCCESS!"