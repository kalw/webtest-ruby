require 'rubygems' if RUBY_VERSION < '1.9' 
require 'watir-webdriver'
require 'watir-webdriver-performance'
require 'headless'
require 'selenium/webdriver'
require 'browsermob/proxy'
require 'har'
require 'yaml'
require 'logger'
require 'trollop'
require 'em-http'
require 'faye/websocket'
require 'json'
require 'webkit_remote'
require 'sinatra/base'
require "sinatra/reloader" 
require 'sinatra/twitter-bootstrap'
require 'haml'



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
  opt :cycles, "cycles numbers , i.e. wo/cache then w/cache "
  opt :failsafe, "wait for 20 sec after onready state in order to catch some RIA long loading sites"
        
end
#Trollop::die "need at least one url" if ARGV.empty? 
#Trollop::die :file, "must exist" unless File.exist?(opts[:file]) if opts[:file]




#url = "http://www.nissan.fr" # string format , i.e. : http://my_url.gtld/uri?query_string
#name = "#{url.hash}"
#webdriver_type = "watir" # string format , i.e. : watir || selenium
#browser_type = "firefox" # string format , i.e. : chrome || firefox
#har_type = "proxy" # string format , i.e. : proxy || internal
#display = ""
#chrome_settings = %W[ --ignore-certificate-errors --always-authorize-plugins --remote-debugging-port=9222] # --kiosk option for fullscreen/notab chromium ; better looking for x11 screenshot or ffmeg output
#vnc_enabled = false # boolean format. 
#


class Wptrb
  attr_accessor :resuls_path, :url , :name , :webdriver_type , :browser_type , :har_type,
   :display , :chrome_settings , :vnc_enabled , :firefox_settings, :proxy_server,
   :headless, :brawsermob_proxy, :har, :results_path, :proxy_old_settings , :interface_name,
   :options , :debug_option, :logger, :browser, :png_wdr_name , :har_name , :png_x11_name,
   :test_cycles
 
  def initialize(site_url,defaults = {})
    
    defaults = {
      :results_path => File.expand_path(File.dirname(__FILE__)) + "/public/results/",
      :webdriver_type => "watir" ,
      :browser_type => "firefox" ,
      :har_type => "proxy" ,
      :display => "" ,
      :chrome_settings => %W[ --ignore-certificate-errors --always-authorize-plugins --remote-debugging-port=9222 ],
      :vnc_enabled => false ,
      :debug_option => false,
      :test_cycles => 1
      }.merge(defaults)
      @options = defaults
      #@logger = Logger.new(STDOUT)
      pp "Initialize options : #{options.inspect}"
    
    
    
    if File.exists?(ENV["HOME"] + '/.wptrb/settings.yml')
      @config = YAML::load(File.open(ENV["HOME"] + '/.wptrb/settings.yml'))
      log_file = File.open(config["debug_file"], 'a+')
      log_file.sync = true 
      #@logger = Logger.new(log_file)
      if defined?(config["results_path"]) ; @results_path = config["results_path"]  ; end
      if defined?(config["webdriver_type"]) ; @webdriver_type = config["webdriver_type"] ; end
      if defined?(config["browser_type"]) ; @browser_type = config["browser_type"] ; end
      if defined?(config["har_type"]) ; @har_type = config["har_type"] ; end
      if defined?(config["display"]) ; @display = config["display"] ; end
      if defined?(config["chrome_settings"]) ; @chrome_settings = config["chrome_settings"] ; end
      if defined?(config["vnc_enabled"]) ; @vnc_enabled = config["vnc_enabled"] ; end
      if defined?(config["debug_options"]) ; @debug_option = config["debug"] ; end
      if defined?(config["test_cycles"]) ; @test_cycles = config["test_cycles"] ; end
    else
      @results_path = options[:results_path]
      @webdriver_type = options[:webdriver_type]
      @browser_type = options[:browser_type]
      @har_type = options[:har_type]
      @display = options[:display]
      @chrome_settings = options[:chrome_settings]
      @vnc_enabled = options[:vnc_enabled]
      @debug_option = options[:debug_options]
      @test_cycles = options[:test_cycles]
      @failsafe = options[:failsafe]
    end
    
    #@logger.info pp @chrome_settings.inspect
    
    if @debug_option 
      #@logger.level = Logger::DEBUG 
    else
      #@logger.level = Logger::ERROR
    end
    
    unless site_url[/^http:\/\//] || site_url[/^https:\/\//]
      site_url = 'http://' + site_url
    end
    @url  = site_url
    @name = "#{Time.now.hash}"
    @name = "#{name}".gsub(/-/,"")
    @results_path = "#{results_path}#{name}/"
    #@logger.debug "Name : #{name} | Result Path : #{results_path}"
    
    @firefox_settings = Selenium::WebDriver::Firefox::Profile.new
    @firefox_settings.assume_untrusted_certificate_issuer=false
    

    @firefox_settings["extensions.firebug.currentVersion"]    = "1.10.6" # avoid 'first run' tab
    @firefox_settings["extensions.firebug.previousPlacement"] = 1
    @firefox_settings["extensions.firebug.allPagesActivation"] = "on"
    @firefox_settings["extensions.firebug.onByDefault"]       = true
    @firefox_settings["extensions.firebug.defaultPanelName"]  = "net"
    @firefox_settings["extensions.firebug.net.enableSites"]   = true
    @firefox_settings["extensions.firebug.DBG_NETEXPORT"] = false
    @firefox_settings["extensions.firebug.consoleexport.active"] = false
    @firefox_settings["extensions.firebug.netexport.autoExportToFile"] = true
    @firefox_settings["extensions.firebug.netexport.defaultLogDir"] = "#{results_path}"
    @firefox_settings["extensions.firebug.netexport.showPreview"] = false
    @firefox_settings["extensions.firebug.netexport.alwaysEnableAutoExport"] = true
    @firefox_settings["extensions.firebug.netexport.Automation"] = true
    @firefox_settings["extensions.firebug.netexport.sendToConfirmation"] = false
    @firefox_settings["extensions.firebug.netexport.saveFiles"] = true
    
    
  end
  
  def simulate_display()
    if @display == ""
      @headless = Headless.new
      
      @headless.start
      @display = @headless.display
      #@logger.debug "Xvfb started on : #{display}"		
    else
    end
    @chrome_settings += %W[ --display=:#{display} ]
    #@logger.debug "display set : #{display}"
    if @vnc_enabled
      system("x11vnc -display :#{display}.0 -ncache 10 &")
      #@logger.debug "x1vnc started"
    end
  end

  def proxy(path)
    if har_type == "proxy" 
      @brawsermob_proxy = BrowserMob::Proxy::Server.new(path)
      @brawsermob_proxy.start
      @proxy_server = brawsermob_proxy.create_proxy
      @proxy_server.new_har("#{name}", :capture_headers => true, :capture_content => true)
      @chrome_settings += %W[ --proxy-server=#{proxy_server.host}:#{proxy_server.port} ]
      @firefox_settings.proxy = Selenium::WebDriver::Proxy.new :http => "#{proxy_server.host}:#{proxy_server.port}"
      @firefox_settings['network.proxy.type'] = 1
      @firefox_settings['network.proxy.http'] = "#{proxy_server.host}"
      @firefox_settings['network.proxy.http_port'] = proxy_server.port
      @firefox_settings['network.proxy.ssl'] = "#{proxy_server.host}"
      @firefox_settings['network.proxy.ssl_port'] = proxy_server.port
      #@firefox_settings['devtools.chrome.enabled'] = true
      if RUBY_PLATFORM.downcase.include?("darwin") && browser_type == "chrome"
        @interface_name = %x(networksetup -listnetworkserviceorder | grep -C1 en0 | head -n1  | awk '{print $2}')
        #@logger.debug "#{interface_name}"
        @proxy_old_settings = %x(networksetup -getwebproxystate #{interface_name})
        proxy_set = `/usr/sbin/networksetup -setwebproxy #{interface_name} #{proxy_server.host} #{proxy_server.port}`
        proxy_activated = `networksetup -setwebproxystate #{interface_name} on`
        proxy_old_status = %W(`networksetup -getwebproxy #{interface_name}`)
        #@logger.debug "#{proxy_old_status}"
      end
      #@logger.debug "proxy set : #{proxy_server.host} #{proxy_server.port}"
    end
  end
  
  def chrome_get_har(url)
    if har_type == "internal"



    end
  end


  def test_url(browser,webdriver)
    if !FileTest::directory?("#{results_path}")
      Dir::mkdir("#{results_path}")
    end
    
    @test_cycles.to_i.times do |view_index|
      @png_wdr_name={}
      @png_x11_name={}
      @har_name={}
      @png_wdr_name["#{view_index}"] = "#{results_path}#{name}#{view_index}.webdriver.png"
      @png_x11_name["#{view_index}"] = "#{results_path}#{name}#{view_index}.x11.png"
      @har_name["#{view_index}"] = "#{results_path}#{name}#{view_index}.har"
      # browser_type == "chrome" && webdriver_type == "watir"
      if browser == "chrome" && webdriver == "watir"
        #@logger.debug "chrome settings set : #{pp chrome_settings}"
        if view_index == 0
          @browser = Watir::Browser.new :chrome , :switches => chrome_settings
          screen_width = @browser.execute_script("return screen.width;")
          screen_height = @browser.execute_script("return screen.height;")
          @browser.driver.manage.window.resize_to(screen_width,screen_height)
          @browser.driver.manage.window.move_to(0,0)
        end
        #	headless.start_capture
        pp "test_url : #{url} && har_type = #{har_type} && har_name = #{har_name["#{view_index}"]}"
        if har_type == "proxy"
          @browser.goto "#{url}"
          sleep 20 # some sites need more time to render even after onreadystate
          # need to calculate onload and on onContentLoad for har injection later
          #performance_timings = browser.execute_script("return window.performance.timing ;")
          #pp performance_timings.inspect
        else
            %x(chrome-har-capturer --host 127.0.0.1 --port 9222 --output #{har_name["#{view_index}"]} #{url})
            sleep 20 # some sites need more time to render even after onreadystate
#         EM.run do
#            # Chrome runs an HTTP handler listing available tabs
#            conn = EM::HttpRequest.new('http://localhost:9222/json').get
#            conn.callback do
#              resp = JSON.parse(conn.response)
#              puts "#{resp.size} available tabs, Chrome response: \n#{resp}"
#
#              # connect to first tab via the WS debug URL
#              ws = Faye::WebSocket::Client.new(resp.first['webSocketDebuggerUrl'])
#              ws.onopen = lambda do |event|
#                # once connected, enable network tracking
#                ws.send JSON.dump({id: 1, method: 'Network.enable'})
#
#                # tell Chrome to navigate to twitter.com and look for "chrome" tweets
#                ws.send JSON.dump({
#                  id: 1,
#                  method: 'Page.navigate',
#                  params: {url: "#{url}"}
#                })
#              end
#
#              ws.onmessage = lambda do |event|
#                # print event notifications from Chrome to the console
#                pp [:new_message, JSON.parse(event.data)]
#              end
#            end
#          end
        end
        if !@headless.nil?
      	  @headless.take_screenshot("#{png_x11_name["#{view_index}"]}")
        end
        @browser.screenshot.save("#{png_wdr_name["#{view_index}"]}")
      end

      # browser_type == "firefox" && webdriver_type == "watir"
      if browser == "firefox" && webdriver == "watir"
        if har_type == "proxy"
          # 
        else
          @firefox_settings.add_extension "lib/firefox/addons/firebug-1.10.6.xpi"
          @firefox_settings.add_extension "lib/firefox/addons/fireStarter-0.1a6.xpi"
          @firefox_settings.add_extension "lib/firefox/addons/netExport-0.9b3.xpi"
        end
        if view_index == 0
          driver = Selenium::WebDriver.for :firefox, :profile => firefox_settings
          @browser = Watir::Browser.new(driver)
          screen_width = @browser.execute_script("return screen.width;")
          screen_height = @browser.execute_script("return screen.height;")
          @browser.driver.manage.window.resize_to(screen_width,screen_height)
          @browser.driver.manage.window.move_to(0,0)
        end
        #	headless.start_capture
        if har_type == "proxy"
          @browser.goto "#{url}"
          sleep 20 # some sites need more time to render even after onreadystate
          # need to calculate onload and on onContentLoad for har injection later
          #performance_timings = browser.execute_script("return window.performance.timing ;")
          #pp performance_timings.inspect
        else
          sleep 5 # wait for plugins to load correctly
          @browser.goto "#{url}"
          Timeout::timeout(300) {
            while (true) do
              if !Dir.glob(Dir["#{File.expand_path(File.dirname(__FILE__))}/public/results/#{name}/*.har"].grep(/\+/)).empty?
                file_name = Dir.glob(Dir["#{File.expand_path(File.dirname(__FILE__))}/public/results/#{name}/*.har"].grep(/\+/))
                File.rename(file_name[0],"#{har_name["#{view_index}"]}")
                break
              end
              sleep 0.5
            end
          }
        end
        if !@headless.nil?
          @headless.take_screenshot("#{png_x11_name["#{view_index}"]}")
        end
        @browser.screenshot.save("#{png_wdr_name["#{view_index}"]}")
      end

      # browser_type == "chrome" && webdriver_type == "selenium"
      if browser == "chrome" && webdriver == "selenium"
        if view_index == 0
          @browser = Selenium::WebDriver.for :chrome ,  :switches => chrome_settings
          screen_width = @browser.execute_script("return screen.width;")
          screen_height = @browser.execute_script("return screen.height;")
          @browser.driver.manage.window.resize_to(screen_width,screen_height)
          @browser.driver.manage.window.move_to(0,0)
        end
        #	headless.start_capture
        if har_type == "proxy"
          @browser.get "#{url}"
          sleep 20 # some sites need more time to render even after onreadystate
          # need to calculate onload and on onContentLoad for har injection later
          #performance_timings = browser.execute_script("return window.performance.timing ;")
          #pp performance_timings.inspect
        else
          chrome_get_har("#{url}")
        end

        if !@headless.nil?
        	@headless.take_screenshot("#{png_x11_name["#{view_index}"]}")
        end
        @browser.save_screenshot("#{png_wdr_name["#{view_index}"]}")
      end

      # browser_type == "firefox" && webdriver_type == "selenium"
      if browser == "firefox" && webdriver == "selenium"
        if har_type == "proxy"
          # 
        else
          @firefox_settings.add_extension "lib/firefox/addons/firebug-1.11.0b3.xpi"
          @firefox_settings.add_extension "lib/firefox/addons/fireStarter-0.1a6.xpi"
          @firefox_settings.add_extension "lib/firefox/addons/netExport-0.9b3.xpi"
        end
        if view_index == 0
          @browser = Selenium::WebDriver.for :firefox , :profile => firefox_settings
          screen_width = @browser.execute_script("return screen.width;")
          screen_height = @browser.execute_script("return screen.height;")
          @browser.driver.manage.window.resize_to(screen_width,screen_height)
          @browser.driver.manage.window.move_to(0,0)
        end
        #	headless.start_capture
        if har_type == "proxy"
          @browser.get "#{url}"
          sleep 20 # some sites need more time to render even after onreadystate
          # need to calculate onload and on onContentLoad for har injection later
          #performance_timings = browser.execute_script("return window.performance.timing ;")
          #pp performance_timings.inspect
        else
          sleep 5 # wait for plugins to load correctly
          @browser.goto "#{url}"
          # sleep 20 # wait for netexport har creation
          Timeout::timeout(60) {
            while (true) do
              if !Dir.glob(Dir["#{File.expand_path(File.dirname(__FILE__))}/public/results/#{name}/*.har"].grep(/\+/)).empty?
                file_name = Dir.glob(Dir["#{File.expand_path(File.dirname(__FILE__))}/public/results/#{name}/*.har"].grep(/\+/))
                File.rename(file_name[0],"#{har_name["#{view_index}"]}")
                break
              end
              sleep 0.5
            end
          }
        end
        if !@headless.nil?
        	@headless.take_screenshot("#{png_x11_name["#{view_index}"]}") 
        end
        @browser.save_screenshot("#{png_wdr_name["#{view_index}"]}")
      end
    
      if @har_type == "proxy" 
        @har = @proxy_server.har
        pp @har.to_json
        @har.save_to "#{har_name["#{view_index}"]}"
        pp "#{har_name["#{view_index}"]}.har"
 
      end
    end
    @browser.close
    if !@headless.nil?
      @headless.destroy
    end
    
    if @har_type == "proxy"
      @brawsermob_proxy.stop
      if RUBY_PLATFORM.downcase.include?("darwin") && browser_type == "chrome"
        proxy_off = `networksetup -setwebproxystate #{i} off`
      end
    end
  end

end


 

class WptrbWww < Sinatra::Base
  configure do
    #set :my_config_property, 'hello world'
    set :app_file, __FILE__
    set :root, File.dirname(__FILE__)
    set :bind, '0.0.0.0'
    set :port, 4567
    set :run, false
    set :logging, false
    register Sinatra::Reloader
    register Sinatra::Twitter::Bootstrap::Assets
    enable :reloader
  end
  #enable :inline_templates
  #enable :sessions
  #set :session_secret, ENV["SESSION_KEY"] || 'too secret'
  
  get '/' do
    #haml:index,:locals =>{:coincoin => "#{settings.my_config_property}"}
    haml:index
  end
    
  get '/test/' do
    pp "test page params : #{params.inspect}"
    test = Wptrb.new(params[:url])
    if defined?(params[:b]) ; test.browser_type     = params[:b] ; end
    if defined?(params[:w]) ; test.webdriver_type   = params[:w] ; end
    if defined?(params[:h]) ; test.har_type         = params[:h] ; end
    if params[:c] == "2"
       test.test_cycles = "2"
    else
      test.test_cycles = "1"
    end
      
    pp "Testing with : #{test.inspect}"
    pp "Browser : #{test.browser_type}"
    pp "Har_type : #{test.har_type}"
    pp "Cycles : #{test.test_cycles}"
    Thread.abort_on_exception = true
    Thread.new do
      test.simulate_display
      if test.har_type == "proxy"
        test.proxy("lib/browsermob-proxy/2.0-beta-6/bin/browsermob-proxy")
      end
      test.test_url("#{test.browser_type}","#{test.webdriver_type}")
    end
  	haml:test,:locals => {
      :test => test,
      :debug => params[:debug],
      :www_proxy => test.har_type,
      :www_webdriver => test.webdriver_type,
      :www_browser => test.browser_type,
      :www_url => test.url,
      :cycles => test.test_cycles
    }
  end
    
  get '/har/' do
    erb:har
  end
  get '/display/' do
    defined?(params[:cycles]) ? cycles = params[:cycles] : cycles = test.options[:test_cycles]
    haml:display,:locals => {
      :name => params[:name],
      :host => request.env["SERVER_NAME"],
      :port => request.port,
      :yslow => params[:yslow ],
      :www_url => params[:www_url],
      :cycles => cycles
    }
  end
  
  
  
end

if [:www]
  WptrbWww.run! do |server|
    server.config[:AccessLog] = []
    server.config[:Logger] = WEBrick::Log::new("/dev/null")
  end
end












