#!/usr/bin/env sh
rm ~/.local/share/fonts/$1*.pcf
sudo rm -f /usr/share/fonts/bitmap/$1*.pcf
sudo mkfontdir /usr/share/fonts/bitmap
sudo mkfontdir /usr/share/fonts
sudo fc-cache
xset fp rehash
