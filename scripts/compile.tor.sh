# https://tor.stackexchange.com/questions/75/how-can-i-install-tor-from-the-source-code-in-the-git-repository

if [ "$cpu" = "armv6l" ]; then
  echo "# running on armv6l - need to compile Tor from source"
  # https://tor.stackexchange.com/questions/75/how-can-i-install-tor-from-the-source-code-in-the-git-repository
  sudo apt-get install -y git build-essential automake libevent-dev libssl-dev zlib1g-dev
  git clone https://git.torproject.org/tor.git
  cd tor
  ./autogen.sh
  ./configure --disable-asciidoc
  make
  make install


sudo systemctl unmask tor
sudo systemctl enable tor
sudo systemctl start tor




https://2019.www.torproject.org/docs/debian#source

if [ "$cpu" = "armv6l" ]; then
  echo "# running on armv6l - need to compile Tor from source"
  apt install build-essential fakeroot devscripts
  apt build-dep tor deb.torproject.org-keyring
  mkdir ~/debian-packages; cd ~/debian-packages
  apt source tor
  cd tor-*
  debuild -rfakeroot -uc -us
  cd ..
  dpkg -i tor_*.deb
  



You need to add the following entries to /etc/apt/sources.list or a new file in /etc/apt/sources.list.d/:

    deb https://deb.torproject.org/torproject.org buster main
    deb-src https://deb.torproject.org/torproject.org buster main

Then add the gpg key used to sign the packages by running the following commands at your command prompt:

    # curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --import
    # gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -

We provide a Debian package to help you keep our signing key current. It is recommended you use it. Install it with the following commands:

    # apt update

    # apt install build-essential fakeroot devscripts
    # apt build-dep tor deb.torproject.org-keyring

Then you can build Tor in ~/debian-packages:

    $ mkdir ~/debian-packages; cd ~/debian-packages
    $ apt source tor
    $ cd tor-*
    $ debuild -rfakeroot -uc -us
    $ cd ..

Now you can install the new package:

    # dpkg -i tor_*.deb

Now Tor is installed and running. Move on to step two of the "Tor on Linux/Unix" instructions. 