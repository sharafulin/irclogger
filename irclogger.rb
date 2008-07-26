$:.unshift File.join(File.dirname(__FILE__), '/vendor/sinatra/lib/')
require 'sinatra'
require 'date'

## DB ###########################
require 'sequel'
Sequel.connect 'mysql://root@localhost/irclogs'
class Message < Sequel::Model(:irclog)
  def message_type
    return "msg" if msg?
    return "info" if info?
    ""
  end

  def msg?
    ! nick.blank?
  end

  def info?
    ! msg?
  end
end


helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def partial(template, *args)
    options = args.extract_options!
    options.merge!(:layout => false)
    if collection = options.delete(:collection) then
      collection.inject([]) do |buffer, member|
        buffer << erb(template, options.merge(:layout =>
        false, :locals => {template.to_sym => member}))
    end.join("\n")
    else
      erb(template, options)
    end
  end

  def relative_day(day) 
    case day
    when "today": Date.today.strftime("%Y-%m-%d")
    when "yesterday": (Date.today - 1).strftime("%Y-%m-%d")
    else Date.today
    end
  end
end

## Web ##########################
get '/' do
  erb :index
end

get '/:channel/' do
  @channel = params[:channel]
  redirect "/#{@channel}/today"
end

get '/:channel/:date' do
  @channel = params[:channel]
  @date = params[:date]

  begin
    @base = Date.parse(@date)
  rescue
    redirect "/#{@channel}/#{relative_day(@date)}"
  end

  @begin = Time.local(@base.year, @base.month, @base.day)
  @end   = Time.local(@base.year, @base.month, @base.day + 1)
  @messages = Message.filter(:timestamp > @begin.to_i).
                      filter(:timestamp < @end.to_i).
                      filter(:channel => "##{@channel}").
                      order(:timestamp)

  @day_before = (@base - 1)
  @day_after = (@base + 1)
  erb :log
end

## Monkey Patching #############
class Fixnum 
  def minutes
    self * 60
  end
end