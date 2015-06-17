require 'yaml'
require 'tilt'
require 'ostruct'

def to_ostruct(object)
  case object
  when Hash
    OpenStruct.new(Hash[object.map {|k, v| [k, to_ostruct(v)] }])
  when Array
    object.map {|x| to_ostruct(x) }
  else
    object
  end
end

def split(filearg)
  filename=filearg.split('.')[0]
  return filename.split('/')
end

def config()
  site = YAML::load_file('site.yaml')
  return to_ostruct(site)
end

def update(s)
  structure=split(s)
  changed=structure[3..-1].join('/')
  context = config()
  template = Tilt::HamlTemplate.new(context.template.dir+context.template.name)
  File.open( context.output_dir+changed+".html", "w") do |file|
      file.write template.render(context) {
          Tilt::HamlTemplate.new( s ).render(context)
      }
  end
end
s=ARGV[0]
context = config()
print s.sub(context.source_dir,'')
structure=split(s)
if structure[2]=='layouts' then
  print 'layout updated'
  updates=Dir.glob(context.source_dir+'pages/**/*').select{ |e| File.file? e }
  updates.each{ |page|
    print "update #{page}\n"
    update(page)
  }
else 
  update(s)
end
