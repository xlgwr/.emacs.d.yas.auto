sudo apt-get install zsh fbterm
sudo add-apt-repository ppa:apt-fast/stable
sudo add-apt-repository ppa:cassou/emacs
sudo add-apt-repository ppa:chris-lea/node.js-legacy
sudo add-apt-repository ppa:rwky/redis
sudo apt-get update && sudo apt-get install apt-fast && sudo apt-get install libc6:i386 libstdc++6:i386 emacs24 node curl libxss1 && sudo apt-get install redis mongodb-org && sudo apt-get upgrade
curl -L get.rvm.io | bash -s stable
. ~/.rvm/scripts/rvm
rvm install ruby
gem sources --remove https://rubygems.org/
gem sources -a https://ruby.taobao.org/
gem install rails --no-doc --no-ri
gem update --no-doc --no-ri
# ntlmaps-setup-0.9.9.6 proxy
sudo wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb  
sudo dpkg -i google-chrome*.deb  
   

