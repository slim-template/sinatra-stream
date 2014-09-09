require 'bundler/setup'
require 'sinatra'
require 'slim'
require 'bigdecimal/math'

class Debug < BasicObject
  def initialize(obj)
    @obj = obj
  end

  def method_missing(*args, &b)
    ::Kernel.puts args.inspect
    @obj.send(*args, &b)
  end
end

helpers do
  def render(engine, template, options = {}, locals = {}, &block)
    # Slim calls the option :streaming, but Sinatra has a #stream method
    # so we also support the :stream option.
    options[:streaming] ||= options.delete(:stream)

    # We are not streaming. Call super implementation and
    # just ensure that the @_out_buf is restored afterwards.
    unless options[:streaming]
      old = @_out_buf
      begin
        return super
      ensure
        @_out_buf = old
      end
    end

    # Engine specific stuff, currently only :slim
    case engine
    when :slim
      # We use the Temple generator without preamble and postamble
      # which is suitable for streaming.
      options[:generator] = Temple::Generator
    else
      raise "Streaming is not supported for #{engine}"
    end

    # There is an output buffer present. We are already streaming, continue!
    if @_out_buf
      # Check if we are really streaming...
      raise 'You are trying to stream from within a unstreamed layout' unless @_out_buf.is_a? Sinatra::Helpers::Stream
      return super
    end

    # Create a new stream
    stream do |out|
      @_out_buf = Debug.new(out)

      if options[:layout] == false
        # No layout given, start rendering template
        super
      else
        # Layout given
        layout = options[:layout] == nil || options[:layout] == true ? :layout : options[:layout]

        # Invert layout and template rendering order
        super engine, layout, options.merge(layout: false), locals do
          super engine, template, options.merge(layout: false), locals, &block
        end
      end
    end
  end
end

get '/' do
  slim :pi, stream: true
end

get '/nolayout' do
  slim :pi, stream: true, layout: false
end

get '/stream' do
  stream do |out|
    out << 'Sleep...'
    sleep 1
    out << 'Awake!'
  end
end

get '/simple' do
  slim :simple
end

__END__

@@ layout
html
  head
    title Computing PI...
  body
    = yield

@@ headline
| Computing PI

@@ ellipsis
- 3.times do
  - sleep 0.5
  = '.'

@@ pi
h1
  == slim :headline
  == slim :ellipsis, stream: true
- i = 1
- loop do
  = BigMath.PI(i).to_s('F')[i-1]
  - i += 1
  - sleep 0.2
  - if i % 100 == 0
    br

@@ simple
| Hello world!
