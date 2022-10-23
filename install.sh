#!/bin/bash -ex

# install openresty nodejs postgresql
# Note: Need to run this as root
#

# chmod 700 ~/.ssh/*

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

# postgresql
if [ -z "$(dpkg -l | grep -E '^ii\s+postgresql\s')" ]; then
  # add postgresql latest
  sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
fi

# nodejs
if [ -z $(which node) ]; then
  curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
fi

# dotnet-sdk-6.0
if [ -z $(which dotnet) ]; then
  wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb
fi

# github cli
if [ -z $(which gh) ]; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
fi

sudo apt-get -q update

install nodejs
install unzip
install make
install gcc
install libpcre3-dev
install libssl-dev
install perl
install build-essential
install curl
install zlib1g
install zlib1g-dev

npm_global_install yarn
npm_global_install env-cmd

# install openresty
PROJECT_DIR=$PWD
OPENRESTY_VER=1.21.4.1
OPENRESTY_DIR=/usr/local
OPENRESTY_PATH="${OPENRESTY_DIR}/openresty/bin:${OPENRESTY_DIR}/openresty/nginx/sbin:${OPENRESTY_DIR}/openresty/luajit/bin"
PATH="$OPENRESTY_PATH:$PATH"
BASH_RC=~/.profile
if [ ! -z "$(grep openresty/bin $BASH_RC)" ]; then
  echo "openresty path already written to ${BASH_RC}";
else
  echo "export PATH=$OPENRESTY_PATH:\$PATH" >> ${BASH_RC};
  echo "add $OPENRESTY_PATH to ${BASH_RC}"
fi
if [ ! -f ${OPENRESTY_DIR}/openresty/bin/openresty ]; then
  cd /tmp
  if [ ! -f openresty-${OPENRESTY_VER}.tar.gz ]; then
    wget https://openresty.org/download/openresty-${OPENRESTY_VER}.tar.gz
  fi
  if [ ! -d openresty-${OPENRESTY_VER}/ ]; then
    tar -xvf openresty-${OPENRESTY_VER}.tar.gz
  fi
  cd openresty-${OPENRESTY_VER}/
  #  --with-http_geoip_module
  ./configure --prefix=${OPENRESTY_DIR}/openresty --with-pcre-jit -j8
  make -j4 && make install
  # service openresty stop
  # pgrep -x nginx && killall nginx
  opm get ledgetech/lua-resty-http
  opm get bungle/lua-resty-template
  opm get fffonion/lua-resty-openssl
  opm get xiangnanscu/pgmoon
  opm get xiangnanscu/lua-resty-inspect
else
  echo "openresty already installed"
fi

# luarocks
LUAROCKS_VER='3.9.1'
LUAROCKS_FD=luarocks-${LUAROCKS_VER}
LUAROCKS_GZ=${LUAROCKS_FD}.tar.gz
if [ ! -f ${OPENRESTY_DIR}/openresty/luajit/bin/luarocks ]; then
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

  # luarocks install  --tree lua_modules luasocket
  cd $PROJECT_DIR
  luarocks install luasocket
  luarocks install luafilesystem
  luarocks install luacheck
  luarocks install lpeg
  luarocks install ljsyscall
  luarocks install argparse
  luarocks install tl
else
  echo "luarocks already installed"
fi

if [ -z "$(dpkg -l | grep -E '^ii\s+postgresql\s')" ]; then
  if [ -z $PG_PASSWORD ]; then
    read -p "please provide postgresql password for user postgres:" PG_PASSWORD
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

  sudo service postgresql restart
  sudo -u postgres psql -w postgres <<EOF
    ALTER USER postgres PASSWORD '$PG_PASSWORD';
EOF

else
  echo "postgresql already installed"
fi

# install dotnet-sdk-6.0
if [ -z $(which dotnet) ]; then
  wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb
  sudo apt-get update && sudo apt-get install -y dotnet-sdk-6.0
fi

# install github cli
if [ -z $(which gh) ]; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y
fi

git config --global user.email "280145668@qq.com"
git config --global user.name "xiangnan"
git config --global receive.denyCurrentBranch updateInstead
git config --global receive.advertisePushOptions true