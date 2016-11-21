# webtest-ruby
# Version:  0.1

FROM                    ubuntu:16.04
MAINTAINER              A CHAPPAZ, Regis A. Despres

#============================================
# can specify versions by CHROME_VERSION;
#  e.g. google-chrome-stable=53.0.2785.101-1
#       google-chrome-beta=53.0.2785.92-1
#       google-chrome-unstable=54.0.2840.14-1
#       latest (equivalent to google-chrome-stable)
#       google-chrome-beta  (pull latest beta)
# can specify versions by FIREFOX_VERSION w/major and minor;
#  e.g. 50.0
#  
#============================================
ARG FIREFOX_VERSION=50.0
ARG GECKODRIVER_VERSION=0.11.1
ARG CHROME_VERSION="google-chrome-stable"
ARG CHROME_DRIVER_VERSION=2.25


#RUN \
RUN apt-get update && \
    apt-get install -y --force-yes wget git imagemagick curl npm ffmpeg zip \
                        zlib1g-dev libcurl4-gnutls-dev xvfb x11vnc dbus-x11 libsqlite3-dev libmagickcore-dev libmagickwand-dev 


#============================================
# Google Chrome
#============================================
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
  && apt-get update -qqy \
  && apt-get -qqy install \
    ${CHROME_VERSION:-google-chrome-stable} \
  && rm /etc/apt/sources.list.d/google-chrome.list \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

#==================
# Chrome webdriver
#==================
RUN wget --no-verbose -O /tmp/chromedriver_linux64.zip https://chromedriver.storage.googleapis.com/$CHROME_DRIVER_VERSION/chromedriver_linux64.zip \
  && rm -rf /opt/selenium/chromedriver \
  && unzip /tmp/chromedriver_linux64.zip -d /opt/selenium \
  && rm /tmp/chromedriver_linux64.zip \
  && mv /opt/selenium/chromedriver /opt/selenium/chromedriver-$CHROME_DRIVER_VERSION \
  && chmod 755 /opt/selenium/chromedriver-$CHROME_DRIVER_VERSION \
  && ln -fs /opt/selenium/chromedriver-$CHROME_DRIVER_VERSION /usr/bin/chromedriver

#=========
# Firefox
#=========
RUN apt-get update -qqy \
  && apt-get -qqy --no-install-recommends install firefox \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
  && wget --no-verbose -O /tmp/firefox.tar.bz2 https://download-installer.cdn.mozilla.net/pub/firefox/releases/$FIREFOX_VERSION/linux-x86_64/en-US/firefox-$FIREFOX_VERSION.tar.bz2 \
  && apt-get -y purge firefox \
  && rm -rf /opt/firefox \
  && tar -C /opt -xjf /tmp/firefox.tar.bz2 \
  && rm /tmp/firefox.tar.bz2 \
  && mv /opt/firefox /opt/firefox-$FIREFOX_VERSION \
  && ln -fs /opt/firefox-$FIREFOX_VERSION/firefox /usr/bin/firefox

#============
# GeckoDriver
#============
RUN wget --no-verbose -O /tmp/geckodriver.tar.gz https://github.com/mozilla/geckodriver/releases/download/v$GECKODRIVER_VERSION/geckodriver-v$GECKODRIVER_VERSION-linux64.tar.gz \
  && rm -rf /opt/geckodriver \
  && tar -C /opt -zxf /tmp/geckodriver.tar.gz \
  && rm /tmp/geckodriver.tar.gz \
  && mv /opt/geckodriver /opt/geckodriver-$GECKODRIVER_VERSION \
  && chmod 755 /opt/geckodriver-$GECKODRIVER_VERSION \
  && ln -fs /opt/geckodriver-$GECKODRIVER_VERSION /usr/bin/geckodriver

RUN git clone --depth=1 https://github.com/kalw/webtest-ruby.git 
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN curl -sL get.rvm.io | bash -s stable
RUN bash -c 'source /etc/profile.d/rvm.sh && rvm requirements && rvm install ruby-2.1 && rvm use ruby-2.1 --default && gem install bundler'
#RUN rm -rf /var/lib/apt/lists/*
#RUN \
RUN ln -s /usr/bin/nodejs  /usr/bin/node
RUN npm install -g chrome-har-capturer 
RUN bash -c 'source /etc/profile.d/rvm.sh && cd webtest-ruby && bundle install'
WORKDIR /webtest-ruby


ENTRYPOINT ["/bin/bash", "-c", "source /etc/profile.d/rvm.sh && ruby ./wptrb.rb ${*}", "--"] 
