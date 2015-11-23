require 'rubygems' if RUBY_VERSION < '1.9'
require 'watir-webdriver'
require 'bundler/setup'
require 'selenium/webdriver'
require 'headless'
#require 'browsermob/proxy'
require 'har'
require 'yaml'
require 'logger'
require 'trollop'
#require 'em-http'
#require 'faye/websocket'
require 'json'
#require 'webkit_remote'
require 'sinatra/base'
require "sinatra/reloader"
require 'sinatra/twitter-bootstrap'
require 'haml'
require 'arachni'
#require 'arachni/ui/cli/output'
#require 'fakeredis'
#require 'resque'
require 'fileutils'
require 'streamio-ffmpeg'



      @headless = Headless.new(:video => { :provider => 'ffmpeg'})

      @headless.start
      @display = @headless.display
      pp "Xvfb started on : #{@display}"


@firefox_settings = Selenium::WebDriver::Firefox::Profile.new
@firefox_settings.add_extension "lib/firefox/addons/har_export_trigger-0.5.0.xpi"
          @firefox_settings["devtools.netmonitor.har.enableAutoExportToFile"] = true
          @firefox_settings["devtools.netmonitor.har.forceExport"] = true
          @firefox_settings["extensions.netmonitor.har.autoConnect"] = true
          @firefox_settings["devtools.netmonitor.har.defaultLogDir"] = "/tmp/"
          @firefox_settings["extensions.netmonitor.har.enableAutomation"] = true
          @firefox_settings["browser.startup.homepage"] = "about:blank"
          @firefox_settings.native_events = false

            driver2 = Selenium::WebDriver.for :firefox, :profile => @firefox_settings
            browser2 = Watir::Browser.new(driver2)
            screen_width = browser2.execute_script("return screen.width;")
            screen_height = browser2.execute_script("return screen.height;")
            browser2.driver.manage.window.resize_to(screen_width,screen_height)
            browser2.driver.manage.window.move_to(0,0)

            @pageRec = browser2.execute_script("return performance.timing;")
            browser2.execute_script("performance.setResourceTimingBufferSize(500);")
            @timingsRec = browser2.execute_script("return performance.getEntriesByType(\"resource\");")
@headless.video.start_capture
            browser2.goto "www.20minutes.fr"
	    sleep 5
            pp "browser gone"
@headless.video.stop_and_save("/tmp/vid")
            browser2.close

