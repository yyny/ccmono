![CCMono preview](preview.png)

These are various scripts for generating `.pcf` fonts from `.bmp` images.

The goal was to turn the [ComputerCraft](https://github.com/dan200/ComputerCraft) [term_font.png](https://github.com/dan200/ComputerCraft/blob/master/src/main/resources/assets/computercraft/textures/gui/term_font.png) file into a valid X11 font.

The scripts are written in [Lua 5.3](https://www.lua.org/manual/5.3/).

The [mkccmono.lua](mkccmono.lua) script creates two files, [ccmono7x10r.pcf](ccmono7x10r.pcf),
 and [ccmono14x20r.pcf](ccmono14x20r.pcf), which is just the `ccmono7x10r.pcf` font
 scaled to twice the size to prevent applications from antialiasing
 the font for font size `14`.

As of right now these scripts map the glyphs to Latin1 (ISO 8859-1),
 I might look into mapping them into [Unicode](https://unicode-table.com/en/), so all characters are
 printable, e.g. mapping glyph 127 onto `U+2592` instead of `U+007F`
 (the `DELETE` character, which is of course not printable).

### Commands

```sh
# Remaking the `.pcf` files
lua ./mkccmono.lua
# Installing the fonts (Ubuntu)
./install.sh
# Testing the font once installed (You might have to restart your application
#  and switch to the ccmono font first)
./testfont.lua
# Uninstalling the fonts
./uninstall.sh
```

### The bitmap (Generated from the original)
![Embedded bitmap](term_font.bmp)
