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

- jdk 
- chromedriver
- chrome
- nodejs
- yslow helper https://github.com/marcelduran/yslow
- chrome har helper https://github.com/cyrus-and/chrome-har-capturer
- imagemagick


Usage :
============

command line :

standalone webview :

- install all requierements 
- bundle install


Todo :
============
 
- interact with wpt
- interact with slowhow
- extract har from devtools in chrome internal 
- add onload and oncontent load from browser into har generated from proxy
- add more test unit
- add travis - OK
- clean up the code
- extract har from chrome without node
