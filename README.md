webtest-ruby [![Build Status](https://travis-ci.org/kalw/webtest-ruby.png?branch=master)](undefined)
============

Standalone webpagetest agent in ruby. Test urls w/browser, gather informations and export them in headless mode



Requirements :
============

Mandatory:

- xvfb
- firefox
- ruby 1.9.x

Optional scope:

- jdk6
- chromedriver
- chrome
- imagemagick 
- ffmpeg 
- VLC

- nodejs
- yslow helper https://github.com/marcelduran/yslow
- chrome har helper https://github.com/cyrus-and/chrome-har-capturer
- pagespeed_sdk (1.9 used for now)


Usage :
============

command line :

standalone webview :

- install all requierements 
- bundle install
- ruby wptrb.rb -w
- launch http://localhost:4567


Todo :
============
 
- interact with wpt - HALF ; get job handled
- interact with slowhow
- extract har from devtools in chrome internal mode - OK w/chrome-har-capturer
- add onload and oncontent load from browser into har generated from proxy mode
- add travis - OK
- add more test unit
- clean up the code
- find more accurate/flexible pagespeed and yslow usage - ALMOST ; using beaconing feat from browser plugins	
- extract har from chrome without node - HALF beaconing from plugin should be ok
	after all, we might need pagespeed chrome_har_capturer in order to interact w/WPT
- enable yslow detection in order to handle execption correctly
- enable chrome-har-capturer detection in order to handle execption correctly
- enable imagemagick detection in order to handle execption correctly
- enable ffmpeg/vlc detection in order to handle execption correctly
- handle self signed ssl certificates - OK remember_certificate_exception-1.0.0-fx.xpi seems to do the trick
- make compatible crosstable making relation w/ firefox/chrome and plugins versions
- detect correct execution of every steps and make related behavior
- handle a trigger regarding video function (Y/N)


Bugs & Enhancements:
============

- combining secscan and w/cache mode show issues twice =)
