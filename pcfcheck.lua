#!/usr/bin/env lua
local pcf = require "pcf"

local function printheader(name)
	print(string.rep('=', 72))
	print('=', name)
	print(string.rep('=', 72))
end

local f = assert(io.open(arg[1], 'rb'))
 -- Test if the `*.pcf` reader runs without crashing
 -- (Un)comment the following lines for more/less information
local result = assert(pcf.read(f))
printheader "METRICS"
io.write(pcf.show_metrics(result))
printheader "PROPERTIES"
io.write(pcf.show_properties(result))
printheader "ENCODINGS"
io.write(pcf.show_encodings(result))
printheader "GLYPH NAMES"
io.write(pcf.show_glyph_names(result))
printheader "SWIDTHS"
io.write(pcf.show_swidths(result))
printheader "ACCELERATORS"
io.write(pcf.show_accelerators(result))
printheader "GLYPHS"
io.write(pcf.show_glyphs(result, { chars_per_row = 16 }))
f:close()
