#!/usr/bin/env sh
rm ~/.local/share/fonts/ccmono*.pcf
sudo rm /usr/share/fonts/bitmap/ccmono*.pcf
sudo mkfontdir /usr/share/fonts/bitmap
sudo mkfontdir /usr/share/fonts
sudo fc-cache
xset fp rehash
