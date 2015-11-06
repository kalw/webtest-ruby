# webtest-ruby
# Version:  0

FROM                    ubuntu:14.04
MAINTAINER              A CHAPPAZ



RUN \
  apt-get install -y wget &&\
  wget -q http://chromedriver.storage.googleapis.com/2.20/chromedriver_linux64.zip && \
  wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
  wget -q -O - "http://keyserver.ubuntu.com:11371/pks/lookup?op=get&search=0x90BD7EACED8E640A" | apt-key add - &&\
echo "deb http://ppa.launchpad.net/mc3man/trusty-media/ubuntu trusty main " > /etc/apt/sources.list.d/ffmpeg.list &&\
  echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list && \
  apt-get update && \
  apt-get install -y google-chrome-stable git firefox ruby bundler zlib1g-dev libcurl4-gnutls-dev ruby-rmagick zip xvfb dbus-x11 npm ffmpeg && \
  rm -rf /var/lib/apt/lists/*
RUN \
  ln -s /usr/bin/nodejs  /usr/bin/node &&\
  npm install -g chrome-har-capturer && \
  git clone https://github.com/kalw/webtest-ruby.git && \
  cd /webtest-ruby && \
  bundle install &&\
  cd / && \
  unzip chromedriver_linux64.zip && \
  mv chromedriver /usr/bin/
COPY run.sh /
RUN chmod +x /run.sh

ENTRYPOINT ["./run.sh"]
CMD ["--help"]
