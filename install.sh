#!/usr/bin/env sh
cp ccmono*.pcf ~/.local/share/fonts
sudo cp ccmono*.pcf /usr/share/fonts/bitmap/
sudo mkfontdir /usr/share/fonts/bitmap
sudo mkfontdir /usr/share/fonts
sudo fc-cache
xset fp rehash
