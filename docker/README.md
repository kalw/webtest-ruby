====================================
dockerfile to build the agent and all its dependencies in a docker image

====================================
Build 

cat Dockerfile|docker build -t wptruby -

====================================
Run

docker run -d wptruby -p wepgagetestserverip -l locationname

