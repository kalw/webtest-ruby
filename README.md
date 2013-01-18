webtest-ruby
============

Standalone webpagetest agent in ruby. Test urls w/browser, gather informations and export them in headless mode



Requirements :
============

Mandatory:

- xvfb
- chromedriver
- chrome
- firefox
- ruby 1.9 x

Optional:

- jdk 
- nodejs
- yslow helper https://github.com/marcelduran/yslow
- imagemagick


Usage :
============

command line :

standalone webview :

- install all requierements


Todo :
============
 
- interact with wpt
- interact with slowhow
- extract har from devtools in chrome internal checks
- add onload and oncontent load from browser into har genrated from proxy
- add more test unit
- add travis
- clean up the code
