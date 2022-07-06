#!/bin/bash -ex

#
# Note: Need to run this as root
#
install() {
  if [ -z $(which $1) ]; then
    sudo apt-get install -y $1
  else
    echo "$1 already installed"
  fi
}
npm_install() {
  if [ -z $(which $1) ]; then
    sudo npm install -g $1
  else
    echo "$1 already installed"
  fi
}

if [ ! -f /usr/local/openresty/bin/openresty ]; then
  # add openresty latest
  sudo apt-get -y install --no-install-recommends wget gnupg ca-certificates
  wget -O - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
  echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list
else
  echo "openresty already installed"
fi

if [ -z "$(dpkg -l | grep -E '^ii\s+postgresql\s')" ]; then
  # add postgresql latest
  sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
else
  echo "postgresql already installed"
fi

sudo apt-get -q update

install unzip
install make
install gcc

if [ -z $(which node) ]; then
  curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo 'nodejs 16 already installed'
fi

npm_install yarn
npm_install env-cmd

# install openresty
OPENRESTY_PATH='/usr/local/openresty/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/luajit/bin'
export PATH=$OPENRESTY_PATH:$PATH
BASH_RC=~/.bashrc
if [ ! -f /usr/local/openresty/bin/openresty ]; then
  sudo apt-get -y -q install openresty
  service openresty stop
  pgrep -x nginx && killall nginx
  echo "openresty installed"
  if [ ! -z $(grep $OPENRESTY_PATH $BASH_RC) ]; then
    echo "openresty path already written to bashrc";
  else
    echo "export PATH=$OPENRESTY_PATH:\$PATH" >> ~/.bashrc;
    echo "add PATH to ${BASH_RC}"
  fi
  # mkdir lua_modules
  opm get ledgetech/lua-resty-http
  opm get bungle/lua-resty-template
  opm get fffonion/lua-resty-openssl
  opm get xiangnanscu/pgmoon
  opm get xiangnanscu/lua-resty-rax
  opm get xiangnanscu/lua-resty-array
  opm get xiangnanscu/lua-resty-object
  opm get xiangnanscu/lua-resty-inspect
else
  echo "openresty already installed"
fi



if [ -z "$(dpkg -l | grep -E '^ii\s+postgresql\s')" ]; then
  [ -z $PG_PASSWORD ] && echo "Plase set PG_PASSWORD" && exit 1
  # install postgresql
  sudo apt-get -y install postgresql
  service postgresql start

  PG_VERSION_VERBOSE=`pg_config --version`
  PG_VERSION=${PG_VERSION_VERBOSE:11:2}

  echo "pg version: $PG_VERSION"

  # modify setting
  sed -i 's/max_connections = 100/max_connections = 400/g' /etc/postgresql/$PG_VERSION/main/postgresql.conf
  sed -i 's/shared_buffers = 128MB/shared_buffers = 256MB/g' /etc/postgresql/$PG_VERSION/main/postgresql.conf
  sed -i 's/#password_encryption = scram-sha-256/password_encryption = md5/g' /etc/postgresql/$PG_VERSION/main/postgresql.conf
  # sed -i 's/"scram-sha-256"/@@@/g' /etc/postgresql/$PG_VERSION/main/pg_hba.conf
  sed -i 's/\(\s\)scram-sha-256/\1md5/g' /etc/postgresql/$PG_VERSION/main/pg_hba.conf
  # sed -i 's/@@@/"scram-sha-256"/g' /etc/postgresql/$PG_VERSION/main/pg_hba.conf
  echo "modify postgresql settings done"

  sudo -u postgres psql -w postgres <<EOF
    ALTER USER postgres PASSWORD '$PG_PASSWORD';
EOF

  sudo -u postgres psql -w postgres <<EOF
    CREATE DATABASE rsks;
EOF
else
  echo "postgresql already installed"
fi

LUAROCKS_VER='3.8.0'
LUAROCKS_FD=luarocks-${LUAROCKS_VER}
LUAROCKS_GZ=${LUAROCKS_FD}.tar.gz
if [ ! -f /usr/local/openresty/luajit/bin/luarocks ]; then
  cd /tmp
  if [ ! -f $LUAROCKS_GZ ]; then
    wget https://luarocks.org/releases/$LUAROCKS_GZ
  fi
  if [ ! -d $LUAROCKS_FD ]; then
    tar zxpf $LUAROCKS_GZ
  fi
  cd $LUAROCKS_FD
  ./configure --prefix=/usr/local/openresty/luajit \
      --with-lua=/usr/local/openresty/luajit/ \
      --lua-suffix=jit \
      --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1
  make && make install
  echo "luarocks ${LUAROCKS_VER} installed"
  # luarocks install  --tree lua_modules luasocket
  luarocks install --global luasocket
  luarocks install --global luafilesystem
  luarocks install --global luacheck
  luarocks install --global lpeg
  luarocks install --global ljsyscall
  luarocks install --global argparse
  luarocks install --global tl
else
  echo "luarocks already installed"
fi
