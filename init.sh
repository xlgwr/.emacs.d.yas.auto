   sudo apt-get install zsh
   sudo apt-get install fbterm
   sudo add-apt-repository ppa:apt-fast/stable
   sudo add-apt-repository ppa:cassou/emacs
   sudo add-apt-repository ppa:chris-lea/node.js-legacy
   sudo add-apt-repository ppa:rwky/redis
   sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
   echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
   sudo  apt-get update && sudo apt-get upgrade
   sudo apt-get install apt-fast
   sudo apt-fast install libc6:i386 libstdc++6:i386
   sudo apt-fast install emacs24 node curl mongodb-org
   curl -L get.rvm.io | bash -s stable
   rvm install 2.1.2
   gem install rails --no-doc --no-ri
   gem update --no-doc --no-ri
   

