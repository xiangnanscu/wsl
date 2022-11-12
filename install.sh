#!/bin/bash -ex

# install openresty nodejs postgresql
# Note: Need to run this as root
#

# chmod 700 ~/.ssh/*

PROJECT_DIR=$PWD
UBUNTU_VER=$(lsb_release -cs)
OPENRESTY_VER=1.21.4.1
OPENRESTY_DIR=/usr/local
OPENRESTY_PATH="${OPENRESTY_DIR}/openresty/bin:${OPENRESTY_DIR}/openresty/nginx/sbin:${OPENRESTY_DIR}/openresty/luajit/bin"
PATH="$OPENRESTY_PATH:$PATH"
BASH_RC=~/.profile

sudo sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 60/g' /etc/ssh/sshd_config
sudo sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 60/g' /etc/ssh/sshd_config
sudo /etc/init.d/ssh reload

install() {
  if [ -z $(which $1) ]; then
    sudo apt-get install -y $1
  else
    echo "$1 already installed"
  fi
}
npm_global_install() {
  if [ -z $(which $1) ]; then
    sudo npm install -g $1
  else
    echo "$1 already installed"
  fi
}
download_build_openresty() {
  cd /tmp
  if [ ! -f openresty-$1.tar.gz ]; then
    wget https://openresty.org/download/openresty-$1.tar.gz
  fi
  if [ ! -d openresty-$1/ ]; then
    tar -xvf openresty-$1.tar.gz
  fi
  cd openresty-$1/
  #  --with-http_geoip_module
  ./configure --prefix=$2/openresty --with-pcre-jit -j8
  make -j4 && make install
}

install_base() {
  sudo apt-get -q update
  install build-essential
  install unzip
  install make
  install gcc
  install libpcre3-dev
  install libssl-dev
  install perl
  install curl
  install zlib1g
  install zlib1g-dev
}

install_nodejs() {
  # nodejs
  if [ -z $(which node) ]; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs
  fi
  npm_global_install yarn
  npm_global_install env-cmd
}

install_openresty() {
  # openresty
  sudo apt-get -y install --no-install-recommends wget gnupg ca-certificates

  if [ $UBUNTU_VER = jammy ]; then
    if [ ! -f /usr/share/keyrings/openresty.gpg ]; then
      wget -O - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
    fi
  else
    wget -O - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
  fi

  if [ ! -f /etc/apt/sources.list.d/openresty.list ]; then
    if [ $UBUNTU_VER = jammy ]; then
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list > /dev/null
    else
      echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main"  | sudo tee /etc/apt/sources.list.d/openresty.list
    fi
  fi

  if [ ! -z "$(grep openresty/bin $BASH_RC)" ]; then
    echo "openresty path already written to ${BASH_RC}";
  else
    echo "export PATH=$OPENRESTY_PATH:\$PATH" >> ${BASH_RC};
  fi

  sudo apt-get -q update
  # install openresty
  if [ ! -f ${OPENRESTY_DIR}/openresty/bin/openresty ]; then
    # download_build_openresty $OPENRESTY_VER $OPENRESTY_DIR
    sudo apt-get -y install openresty
    # service openresty stop
    # pgrep -x nginx && killall nginx
  else
    echo "openresty already installed"
  fi
}

install_luarocks() {
  # luarocks
  LUAROCKS_VER='3.9.1'
  LUAROCKS_FD=luarocks-${LUAROCKS_VER}
  LUAROCKS_GZ=${LUAROCKS_FD}.tar.gz
  if [ ! -f ${OPENRESTY_DIR}/openresty/luajit/bin/luarocks ] && [ -f ${OPENRESTY_DIR}/openresty/bin/openresty ]; then
    cd /tmp
    if [ ! -f $LUAROCKS_GZ ]; then
      wget https://luarocks.org/releases/$LUAROCKS_GZ
    fi
    if [ ! -d $LUAROCKS_FD ]; then
      tar zxpf $LUAROCKS_GZ
    fi
    cd $LUAROCKS_FD
    ./configure --prefix=${OPENRESTY_DIR}/openresty/luajit \
        --with-lua=${OPENRESTY_DIR}/openresty/luajit/ \
        --lua-suffix=jit \
        --with-lua-include=${OPENRESTY_DIR}/openresty/luajit/include/luajit-2.1
    make && make install
    echo "luarocks ${LUAROCKS_VER} installed"
  else
    echo "luarocks already installed"
  fi
}

install_lua_packages() {
  if [ ! -z $(which opm) ]; then
    opm get ledgetech/lua-resty-http
    opm get bungle/lua-resty-template
    opm get bungle/lua-resty-prettycjson
    opm get fffonion/lua-resty-openssl
    opm get xiangnanscu/pgmoon
    opm get xiangnanscu/lua-resty-inspect
  fi
  if [ ! -z $(which luarocks) ]; then
    # luarocks install  --tree lua_modules luasocket
    cd $PROJECT_DIR
    luarocks install luasocket
    luarocks install luafilesystem
    luarocks install luacheck
    luarocks install lpeg
    luarocks install ljsyscall
    luarocks install argparse
    luarocks install tl
  fi
}

install_postgresql() {
  # postgresql
  if [ -z "$(dpkg -l | grep -E '^ii\s+postgresql\s')" ]; then
    # add postgresql latest
    if [ $UBUNTU_VER != jammy ]; then
      sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
      wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
      sudo apt-get -q update
    fi
    # install postgresql
    sudo apt-get -y install postgresql

    PG_VERSION_VERBOSE=`pg_config --version`
    PG_VERSION=${PG_VERSION_VERBOSE:11:2}

    echo "pg version: $PG_VERSION"

    # modify setting
    sudo sed -i 's/max_connections = 100/max_connections = 400/g' /etc/postgresql/$PG_VERSION/main/postgresql.conf
    sudo sed -i 's/shared_buffers = 128MB/shared_buffers = 256MB/g' /etc/postgresql/$PG_VERSION/main/postgresql.conf
    sudo sed -i 's/#password_encryption = scram-sha-256/password_encryption = md5/g' /etc/postgresql/$PG_VERSION/main/postgresql.conf
    sudo sed -i 's/\(\s\)scram-sha-256/\1md5/g' /etc/postgresql/$PG_VERSION/main/pg_hba.conf
    echo "before restart, pg password: $PG_PASSWORD, working dir: $PWD"
    sudo service postgresql restart
    if [ -z $PG_PASSWORD ]; then
      read -p "please provide postgresql password for user postgres:" PG_PASSWORD
    else
      echo "pg password is provided: $PG_PASSWORD"
    fi
    sudo -u postgres psql -w postgres <<EOF
      ALTER USER postgres PASSWORD '$PG_PASSWORD';
EOF

  fi
}


install_dotnet() {
  # install dotnet-sdk-6.0
  if [ -z $(which dotnet) ]; then
    wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    sudo apt-get update && sudo apt-get install -y dotnet-sdk-6.0
  fi
}

install_gh() {
  # github cli
  if [ -z $(which gh) ]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
  fi
}

config_git() {
  git config --global user.email "280145668@qq.com"
  git config --global user.name "xiangnan"
  git config --global receive.denyCurrentBranch updateInstead
  git config --global receive.advertisePushOptions true
}

install_base
install_nodejs
install_openresty
install_luarocks
install_postgresql
install_dotnet
install_gh
install_lua_packages
config_git








