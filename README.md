webtest-ruby [![Build Status](https://travis-ci.org/kalw/webtest-ruby.png?branch=master)](undefined)
============

Standalone webpagetest agent in ruby. Test urls w/browser, gather informations and export them in headless mode



Requirements :
============

Mandatory:

- xvfb
- firefox
- ruby 1.9 x

Optional:

- jdk6
- chromedriver
- chrome
- nodejs
- yslow helper https://github.com/marcelduran/yslow
- chrome har helper https://github.com/cyrus-and/chrome-har-capturer
- imagemagick 
- ffmpeg 


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
- add more test unit
- add travis - OK
- clean up the code
- find more accurate/flexible pagespeed and yslow usage - ALMOST ; using beaconing feat from browser plugins	
- extract har from chrome without node - HALF beaconing from plugin should be ok
- enable yslow detection in order to handle execption correctly
- enable chrome-har-capturer detection in order to handle execption correctly
- enable imagemagick detection in order to handle execption correctly
- enable ffmpeg detection in order to handle execption correctly
- handle self signed ssl certificates