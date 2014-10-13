sudo apt-get install zsh fbterm
sudo add-apt-repository ppa:apt-fast/stable
sudo add-apt-repository ppa:cassou/emacs
sudo add-apt-repository ppa:chris-lea/node.js-legacy
sudo add-apt-repository ppa:rwky/redis
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
sudo apt-get install libxss1  
sudo wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb  
sudo dpkg -i google-chrome*.deb  
sudo  apt-get update && sudo apt-get install apt-fast && sudo apt-fast install libc6:i386 libstdc++6:i386 && sudo apt-fast install emacs24 node curl redis mongodb-org && sudo apt-fast upgrade
curl -L get.rvm.io | bash -s stable
. ~/.rvm/script/rvm
rvm install ruby
gem install rails --no-doc --no-ri
gem update --no-doc --no-ri
# ntlmaps-setup-0.9.9.6 proxy
   

