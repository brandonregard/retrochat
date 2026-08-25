#!/bin/sh
set -eu
cd "$(dirname "$0")"
echo "Installing Tcl/Tk AMD64 prerequisites and RetroChat..."
sudo apt-get update
sudo apt-get install -y chrpath gawk sed libcap2-bin
sudo dpkg -i ./tcltk86-amd64.deb ./retrochat-*-linux-amd64.deb
echo "RetroChat and RetroChat Server are now available in the application menu."
