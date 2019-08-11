#!/usr/bin/env sh
echo "Installing ""$@""..."
cp "$@" ~/.local/share/fonts
sudo cp "$@" /usr/share/fonts/bitmap/
sudo mkfontdir /usr/share/fonts/bitmap
sudo mkfontdir /usr/share/fonts
sudo fc-cache
xset fp rehash
