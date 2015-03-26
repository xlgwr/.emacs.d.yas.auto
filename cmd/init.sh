#14.04 later
sudo add-apt-repository ppa:saiarcot895/myppa
sudo apt-get update
sudo apt-get -y install apt-fast && sudo apt-fast install zsh fbterm emacs24 libxss1 && sudo apt-fast upgrade && sudo apt-fast dist-upgrade
sudo apt-get install curl wget && curl -sL https://deb.nodesource.com/setup_0.12 | sudo bash - && sudo npm install -g cnpm --registry=https://registry.npm.taobao.org
#libc6:i386 libstdc++6:i386
curl -L get.rvm.io | bash -s stable && . ~/.rvm/scripts/rvm && rvm install ruby && gem sources --remove https://rubygems.org/ && gem sources -a https://ruby.taobao.org/ && gem install rails --no-doc --no-ri && gem update --no-doc --no-ri
# ntlmaps-setup-0.9.9.6 proxy
sudo wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo dpkg -i google-chrome*.deb  
   

