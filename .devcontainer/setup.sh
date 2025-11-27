#!/bin/bash
set -e

echo "Setting up markdown-plus.nvim development environment..."

# Update package lists
sudo apt-get update

# Install Neovim stable from official PPA
echo "Installing Neovim stable..."
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:neovim-ppa/stable
sudo apt-get update
sudo apt-get install -y neovim

# Install Lua 5.1 (required for Neovim plugin development)
echo "Installing Lua 5.1..."
sudo apt-get install -y lua5.1 liblua5.1-0-dev

# Install LuaRocks for package management
echo "Installing LuaRocks..."
sudo apt-get install -y luarocks

# Install luacheck (Lua linter)
echo "Installing luacheck..."
sudo luarocks install luacheck

# Install busted (Lua testing framework)
echo "Installing busted..."
sudo luarocks install busted

# Install Rust and Cargo for stylua
echo "Installing Rust and Cargo..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# Install stylua (Lua formatter)
echo "Installing stylua..."
cargo install stylua

# Install lua-language-server for LSP support
echo "Installing lua-language-server..."
sudo apt-get install -y ninja-build
cd /tmp
rm -rf lua-language-server
git clone https://github.com/LuaLS/lua-language-server
cd lua-language-server
./make.sh
sudo cp -r bin/lua-language-server /usr/local/bin/
sudo cp -r bin/main.lua /usr/local/bin/lua-language-server-main.lua
cd /workspaces/markdown-plus.nvim
rm -rf /tmp/lua-language-server

# Create Neovim directories
mkdir -p ~/.config/nvim
mkdir -p ~/.local/share/nvim/site/pack/vendor/start

# Install plenary.nvim (required for tests)
echo "Installing plenary.nvim for testing..."
git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git \
  ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim

# Verify installations
echo ""
echo "Verifying installations..."
echo "Neovim version:"
nvim --version | head -1
echo "Lua version:"
lua -v
echo "LuaRocks version:"
luarocks --version | head -1
echo "luacheck version:"
luacheck --version
echo "busted version:"
busted --version
echo "stylua version:"
stylua --version
echo "lua-language-server: $(command -v lua-language-server || echo 'installed')"

echo ""
echo "✅ Development environment setup complete!"
echo ""
echo "Available commands:"
echo "  make test          - Run all tests"
echo "  make lint          - Run luacheck linter"
echo "  make format        - Format code with stylua"
echo "  make format-check  - Check formatting"
echo "  make check         - Run all CI checks"
echo ""
