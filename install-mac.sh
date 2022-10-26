pip3 install sshuttle
sshuttle --dns -r root@rsks.ren 0.0.0.0/0

# 设置git代理加速homebrew的安装
git config --global http.proxy http://127.0.0.1:49688
git config --global https.proxy https://127.0.0.1:49688
git config --global http.proxy 'socks5://127.0.0.1:49689'
git config --global https.proxy 'socks5://127.0.0.1:49689'

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew intall wget
brew install gh
brew install postgresql@14
brew services start postgresql@14

brew install nodejs
npm install -g yarn env-cmd npm-check-updates

brew install openresty/brew/openresty
brew install luarocks

opm get ledgetech/lua-resty-http
opm get bungle/lua-resty-template
opm get fffonion/lua-resty-openssl
opm get xiangnanscu/pgmoon
opm get xiangnanscu/lua-resty-inspect
luarocks install luasocket
luarocks install luafilesystem
luarocks install luacheck
luarocks install lpeg
luarocks install ljsyscall
luarocks install argparse
luarocks install tl
# git config --global --unset http.proxy
# git config --global --unset https.proxy