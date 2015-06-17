# A sample Guardfile
# More info at https://github.com/guard/guard#readme

## Uncomment and set this to only include directories you want to watch
directories %w(source)

## Uncomment to clear the screen before every task
# clearing :on

## Guard internally checks for changes in the Guardfile and exits.
## If you want Guard to automatically start up again, run guard in a
## shell loop, e.g.:
##
##  $ while bundle exec guard; do echo "Restarting Guard..."; done
##
## Note: if you are using the `directories` clause above and you are not
## watching the project directory ('.'), then you will want to move
## the Guardfile to a watched dir and symlink it back, e.g.
#
#  $ mkdir config
#  $ mv Guardfile config/
#  $ ln -s config/Guardfile .
#
# and, you'll have to watch "config/Guardfile" instead of "Guardfile"

coffeescript_options = {
  input: 'source/assets/js',
  output: 'compiled/assets/javascripts',
  patterns: [%r{^source/assets/javascripts/(.+\.(?:coffee|coffee\.md|litcoffee))$}]
}

guard 'coffeescript', coffeescript_options do
  coffeescript_options[:patterns].each { |pattern| watch(pattern) }
end

# This will concatenate the javascript files specified in :files to public/js/all.js
#
# Specifying every single file in the array like %w(a b c) to maintain the loading order is suggested - See https://github.com/makevoid/guard-concat for more info
#
guard :concat, type: "js", files: %w(), input_dir: "compiled/assets/js", output: "compiled/assets/js/all"

guard :concat, type: "css", files: %w(), input_dir: "compiled/assets/css", output: "compiled/assets/all"

# Sample guardfile block for Guard::Haml
# You can use some options to change guard-haml configuration
# output: 'public'                   set output directory for compiled files
# input: 'src'                       set input directory with haml files
# run_at_start: true                 compile files when guard starts
# notifications: true                send notifictions to Growl/libnotify/Notifu
# haml_options: { ugly: true }    pass options to the Haml engine

guard :shell, input: 'source/haml/pages', output: 'compiled' do
  watch(/^.+(\.html\.haml)$/) do |m|
    `ruby tilt.rb #{m[0]}`
  end
end

guard 'livereload' do
  watch(%r{source/.+\.(erb|haml|slim)$})
  watch(%r{source/assets/.+\.(css|js|html)})
  watch(%r{config/locales/.+\.yml})
end
guard 'rack', :port => 9292 do
  watch('Gemfile.lock')
  watch(%r{^(config|lib|app)/.*})
end

guard 'sass', :input => 'source/sass', :output => 'compiled/assets/stylesheets'
