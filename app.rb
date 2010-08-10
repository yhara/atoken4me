require 'pathname'
require 'sinatra'
require 'rack-flash'
require 'twitter'
require 'haml'
require 'json'
require (Pathname(__FILE__).dirname+"./consumer_token.rb").expand_path

configure do
  enable :sessions
  set :haml, :format => :html5
  set :haml, :escape_html => true
  use Rack::Flash
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get "/" do
  haml :index
end

post "/pin" do
  oauth = Twitter::OAuth.new(params["key"], params["secret"])
  request_token = oauth.consumer.get_request_token
  @authurl = request_token.authorize_url

  @ctoken  = session[:ctoken]  = params["key"]
  @csecret = session[:csecret] = params["secret"]
  session[:rtoken]  = request_token.token
  session[:rsecret] = request_token.secret
  
  haml :pin
end

post "/atoken" do
  redirect "/" if !session[:ctoken] || !session[:csecret] ||
                  !session[:rtoken] || !session[:rsecret]

  pin = params["pin"]

  oauth = Twitter::OAuth.new(session[:ctoken], session[:csecret])
  begin
    @ctoken, @csecret = session[:ctoken], session[:csecret]
    @atoken, @asecret = oauth.authorize_from_request(session[:rtoken],
                                                     session[:rsecret],
                                                     pin)
  rescue OAuth::Unauthorized
    flash[:error] = "Oops! Got 401 Unauthorized."
    redirect "/"
  end

  haml :atoken
end

__END__

@@ layout
!!!
%html
  %head
    %meta(charset="utf-8")
    %title Hello, Haml!
    %style(type="text/css") .error{ border:1px solid black; color:red; }
  %body
    %h1 
      %a(href="/") Atoken4Me
    - if flash[:error]
      .error
        != flash[:error]
    .main
      != yield

@@ index
%h2 Step 1. input your app's token
%p
  Open
  %a(href="http://twitter.com/apps/new" target="blank") http://twitter.com/apps/new
  , fill-in the form.

%form(action="/pin" method="POST")
  %dl
    %dt key
    %dd
      %input(type="text" name="key" value=@ctoken)
    %dt secret
    %dd
      %input(type="text" name="secret" value=@csecret)
    %dt
    %dd
      %input(type="submit")

@@ pin
%h2 Step 2. get the PIN number for you and the app
%p
  Open
  %a(href=@authurl target="blank")= @authurl
  and get the PIN number.
%form(action="/atoken" method="POST")
  %dl
    %dt PIN
    %dd
      %input(type="text" name="pin")
    %dt
    %dd
      %input(type="submit")

@@ atoken
%h2 Step 3. Congraturations! This is your atoken:
%dl
  %dt atoken
  %dd= @atoken
  %dt asecret
  %dd= @asecret
%h3 Example
:erb
  <pre>
  require 'twitter'
  # your app
  oauth = Twitter::OAuth.new('<%=h @ctoken%>', '<%=h @csecret%>')
  # your login
  oauth.authorize_from_access('<%=h @atoken}', '<%=h @asecret%>')
  twitter = Twitter::Base.new(oauth)
  
  require 'pp'
  pp twitter.user_timeline
  <pre>
