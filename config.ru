use Rack::ShowExceptions
use Rack::Static, 
    :urls => ["/images", "/js", "/css"],
    :root => "compiled",
    :index => 'index.html'

run Rack::File.new("compiled")
