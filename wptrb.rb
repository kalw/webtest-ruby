require 'watir-webdriver'
require 'watir-webdriver-performance'
require 'headless'
require 'selenium/webdriver'
require 'browsermob/proxy'
require 'har'
require 'pp'
require 'yaml'
require 'pp'
require 'yaml'
require 'logger'
require 'trollop'
require 'awesome_print'


opts = Trollop::options do
  version "wptrb 0.0.1 @ 2013 Regis A. Despres"
  banner <<-EOS
WTPRB is either a webpagetest agent and a simple url inspector.
  * In simple mode,  browse site url and report some "basic" statistics on stdout
  * Once wpt_server_url and location_name options set,  browse site url and report
  to webpagetest instance.
  * In webview, WPTRB launch a sinatra app that can fire up both mode

Usage:
       wptrb [options] <url>
       
where [options] and <url> are:
EOS

  opt :config, "read or override configuration from file."
  opt :www, "start webview sinatra app."
  opt :browser, "choose browser type , i.e ; chrome|firefox .", :default => "chrome"
  opt :webdriver, "choose webdriver type , i.e ; watir|selenium .", :default => "watir"
  opt :debug, "debug mode. if debug file empty, defaults to debug.log .",
  :type => String , :default => "debug.log"
  opt :wptserver, "fetch/report job from/to webpagetest instance."
  opt :location, "indicate webpagetest location. mandatory if --wptserver is set."
  opt :har, "har creation type, i.e ; browsermob proxy or internal browser method."
  opt :url, "url to inspect in \"http(s)://domain.gtld/uri?query_string format\""
        

end
#Trollop::die "need at least one url" if ARGV.empty? 
#Trollop::die :file, "must exist" unless File.exist?(opts[:file]) if opts[:file]



if File.exists?(ENV["HOME"] + '/.wptrb/settings.yml')
  CONFIG = YAML::load(File.open(ENV["HOME"] + '/.wptrb/settings.yml')) unless defined? CONFIG
  log_file = File.open(CONFIG["debug_file"], 'a+')
  log_file.sync = true 
  logger = Logger.new(log_file) 
  def logger; settings.logger; end 
  #set :logger, logger
  if CONFIG["wptrb_debug"] == "yes"
  logger.level = Logger::DEBUG 
  else
  logger.level = Logger::ERROR
  end
end

url = "http://www.nissan.fr" # string format , i.e. : http://my_url.gtld/uri?query_string
name = "#{url.hash}"
webdriver_type = "watir" # string format , i.e. : watir || selenium
browser_type = "chrome" # string format , i.e. : chrome || firefox
har_type = "proxy" # string format , i.e. : proxy || internal
display = ""
chrome_settings = %W[ --ignore-certificate-errors --always-authorize-plugins --remote-debugging-port=9222] # --kiosk option for fullscreen/notab chromium ; better looking for x11 screenshot or ffmeg output
vnc_enabled = false # boolean format. 



class Wptrb
attr_accessor :resuls_path, :url , :name , :webdriver_type , :browser_type , :har_type,
 :display , :chrome_settings , :vnc_enabled , :firefox_settings, :proxy_server,
 :headless, :brawsermob_proxy, :har, :results_path
 
  def initialize(site_url)
    @results_path = "public/results/"
    @url = site_url
    @name = "#{site_url.hash}"
    @webdriver_type = "watir" # string format , i.e. : watir || selenium
    @browser_type = "chrome" # string format , i.e. : chrome || firefox
    @har_type = "proxy" # string format , i.e. : proxy || internal
    @display = ""
    @chrome_settings = %W[ --ignore-certificate-errors --always-authorize-plugins --remote-debugging-port=9222]
    @vnc_enabled = false # boolean format.  
   
    @firefox_settings = Selenium::WebDriver::Firefox::Profile.new
    @firefox_settings.add_extension "lib/firefox/addons/firebug-1.11.0b3.xpi"
    @firefox_settings.add_extension "lib/firefox/addons/fireStarter-0.1a6.xpi"
    @firefox_settings.add_extension "lib/firefox/addons/netExport-0.9b2.xpi"

    @firefox_settings['extensions.firebug.currentVersion']    = "1.11.0b3" # avoid 'first run' tab
    @firefox_settings["extensions.firebug.previousPlacement"] = 3
    @firefox_settings["extensions.firebug.allPagesActivation"] = "on"
    @firefox_settings["extensions.firebug.onByDefault"]       = true
    @firefox_settings["extensions.firebug.defaultPanelName"]  = "net"
    @firefox_settings["extensions.firebug.net.enableSites"]   = true
    
    @firefox_settings['extensions.firebug.netexport.autoExportToFile'] = true
    @firefox_settings['extensions.firebug.netexport.defaultLogDir'] = "#{results_path}"
    @firefox_settings["extensions.firebug.netexport.showPreview"] = false
    @firefox_settings["extensions.firebug.netexport.alwaysEnableAutoExport"] = true
  end
  
  def simulate_display()
    if @display == ""
      @headless = Headless.new
      @headless.start
      @display = @headless.display		
    else
    end
    @chrome_settings += %W[ --display=:#{display} ]
    puts "display set : #{display}"
    if @vnc_enabled
      system("x11vnc -display :#{display}.0 -ncache 10 &")
      puts "x1vnc started"
    end
  end

  def proxy(path)
    if har_type == "proxy" 
      @brawsermob_proxy = BrowserMob::Proxy::Server.new(path)
      @brawsermob_proxy.start
      @proxy_server = brawsermob_proxy.create_proxy
      @proxy_server.new_har("#{name}", :capture_headers => true)
      @chrome_settings += %W[ --proxy-server=#{proxy_server.host}:#{proxy_server.port} ]
      @firefox_settings.proxy = Selenium::WebDriver::Proxy.new :http => "#{proxy_server.host}:#{proxy_server.port}"
      @firefox_settings["network.proxy.type"] = 1
      @firefox_settings["network.proxy.http"] = "#{proxy_server.host}"
      @firefox_settings["network.proxy.http_port"] = "#{proxy_server.port}"
      puts "proxy set : #{proxy_server.host} #{proxy_server.port}"
    end
  end
  
  def chrome_get_har(url)
    if har_type == "internal"
      require 'em-http'
      require 'faye/websocket'
      require 'json'

      EM.run do
        # Chrome runs an HTTP handler listing available tabs
        conn = EM::HttpRequest.new('http://localhost:9222/json').get
        conn.callback do
          resp = JSON.parse(conn.response)
          puts "#{resp.size} available tabs, Chrome response: \n#{resp}"

          # connect to first tab via the WS debug URL
          ws = Faye::WebSocket::Client.new(resp.first['webSocketDebuggerUrl'])
          ws.onopen = lambda do |event|
            # once connected, enable network tracking
            ws.send JSON.dump({id: 1, method: 'Network.enable'})

            # tell Chrome to navigate to twitter.com and look for "chrome" tweets
            ws.send JSON.dump({
              id: 2,
              method: 'Page.navigate',
              params: {url: '#{url}' + rand(100).to_s}
            })
          end

          ws.onmessage = lambda do |event|
            # print event notifications from Chrome to the console
            p [:new_message, JSON.parse(event.data)]
          end
        end
      end
    end
  end


  def test_url(browser,webdriver)
    # browser_type == "chrome" && webdriver_type == "watir"
    if browser == "chrome" && webdriver == "watir"
      puts "chrome settings set : #{pp chrome_settings}"
      browser = Watir::Browser.new :chrome , :switches => chrome_settings
      #	headless.start_capture
      #browser.goto "#{url}"
      chrome_get_har("#{url}")
      if !@headless.nil?
    	  #@headless.take_screenshot("#{results_path}#{name}.x11.png")
      end
      browser.screenshot.save("#{results_path}#{name}.webdriver.png")
    end

    # browser_type == "firefox" && webdriver_type == "watir"
    if browser == "firefox" && webdriver == "watir"
      driver = Selenium::WebDriver.for :firefox, :profile => firefox_settings
      browser = Watir::Browser.new(driver) 
      #	headless.start_capture
      browser.goto "#{url}"
      if !@headless.nil?
        #@headless.take_screenshot("#{results_path}#{name}.x11.png")
      end
      browser.screenshot.save("#{results_path}#{name}.webdriver.png")
    end

    # browser_type == "chrome" && webdriver_type == "selenium"
    if browser == "chrome" && webdriver == "selenium"
      browser = Selenium::WebDriver.for :chrome ,  :switches => chrome_settings
      #	headless.start_capture
      browser.navigate.to "#{url}"
      if !@headless.nil?
      	#@headless.take_screenshot("#{results_path}#{name}.x11.png")
      end
      browser.screenshot.save("#{results_path}#{name}.webdriver.png")
    end

    # browser_type == "firefox" && webdriver_type == "selenium"
    if browser == "firefox" && webdriver == "selenium"
      browser = Selenium::WebDriver.for :firefox , :profile => firefox_settings 
      #	headless.start_capture
      browser.navigate.to "#{url}"
      if !@headless.nil?
      	#@headless.take_screenshot("#{results_path}#{name}.x11.png")
      end
      browser.screenshot.save("#{results_path}#{name}.webdriver.png")
    end

    if @har_type == "proxy" 
      @har = @proxy_server.har
      pp @har.to_json
      @har.save_to "#{results_path}#{name}.har"
      @brawsermob_proxy.stop
    end
    browser.close
    if !@headless.nil?
      @headless.destroy
    end
  end

end

if opts[:www]
  #require 'sinatra'
  require 'sinatra/base'
  require "sinatra/reloader" 
  require 'sinatra/twitter-bootstrap'
  require 'haml'  
  class WptrbWww < Sinatra::Base
    register Sinatra::Twitter::Bootstrap::Assets
    register Sinatra::Reloader
    #enable :inline_templates
    use Rack::Session::Pool, :expire_after => 2592000
    
    get '/' do
      haml:index
    end
    
    get '/test/' do
      test = Wptrb.new(params[:url])
    	haml:test,:locals => {:test => test}
    end
    
    get '/har/' do
      erb:har
    end
    get '/display/' do
      session[:validate] = "false"
      session[:stats] = "true"
      haml:display,:locals => {:name => params[:name]}
    end
   end
   WptrbWww.run!
end










