#!/usr/bin/env lua
local pcf = require "pcf"
local bmp = require "bmp"

-- Repeat a value n times
local function rep(v, n)
	local result = {}
	for i=1,n do
		result[i] = v
	end
	return result
end

local f = assert(io.open('./term_font.bmp', 'rb'))
local d = bmp.read(f)
f:close()

-- Display the bitmap with a nice border around it
io.write('+',string.rep('-',d.width),'+','\n')
for y=1,d.height do
	io.write('|')
	for x=1,d.width do
		io.write(d.data[y][x] == 1 and '#' or '.')
	end
	io.write('|\n')
end
io.write('+',string.rep('-',d.width),'+','\n')

-- Function for calculating metrics of each glyph
local function calc_metrics(glyphs,w,h,lsb,rsb)
	local result = {}
	for n=1,#glyphs do
		local glyph = glyphs[n]
		local left_sided_bearing = 0
		for x=1,lsb do
			local done = false
			for y=1,h do
				if glyph[(y-1)*h+x] then
					done = true
					break
				end
			end
			if done then break end
			left_sided_bearing = left_sided_bearing + 1
		end
		local right_side_bearing = 0
		for x=w,rsb do
			local done = false
			for y=1,h do
				if glyph[(y-1)*h+x] then
					done = true
					break
				end
			end
			if done then break end
			right_side_bearing = right_side_bearing + 1
		end
		local character_ascent = 0
		for y=1,h do
			local done = false
			for x=1,w do
				if glyph[(y-1)*h+x] then
					done = true
					break
				end
			end
			if done then break end
			character_ascent = character_ascent + 1
		end
		local character_descent = 0
		for y=1,h do
			local done = false
			for x=1,w do
				if glyph[(y-1)*h+x] then
					done = true
					break
				end
			end
			if done then break end
			character_descent = character_descent + 1
		end
		result[n] =
			{ left_sided_bearing   = left_sided_bearing
			, right_side_bearing   = right_side_bearing + w
			, character_width      = w
			, character_ascent     = 9 - character_ascent
			, character_descent    = 2 - character_descent
			, character_attributes = 0
			}
	end
	return result
end
-- Function for calculating metric bounds according to function `f` (which should be math.min or math.max)
local function calc_bounds(metrics, f, w)
	local keys = {'left_sided_bearing', 'right_side_bearing', 'character_width', 'character_ascent', 'character_descent', 'character_attributes'}
	local r = {}
	for n=1,#metrics do
		for i=1,#keys do
			local key = keys[i]
			if not r[key] then
				r[key] = metrics[n][key]
			end
			r[key] = f(metrics[n][key], r[key])
		end
	end
	return r
end
-- Function for obtaining the value of a property with a default value of an empty string
local function def(prop, v)
	return prop and prop.value or v or ''
end

local out = pcf.create()
out.metrics = rep(
	{ left_sided_bearing   = 0
	, right_side_bearing   = 6
	, character_width      = 6
	, character_ascent     = 8
	, character_descent    = 1
	, character_attributes = 0
	}, 256)
out.properties["FONTNAME_REGISTRY"] = ""
out.properties["FOUNDRY"] = "Misc"
out.properties["FAMILY_NAME"] = "CCMono"
out.properties["WEIGHT_NAME"] = "Medium"
out.properties["SLANT"] = "R"
out.properties["SETWIDTH_NAME"] = "Normal"
out.properties["ADD_STYLE_NAME"] = ""
out.properties["PIXEL_SIZE"] = 10
out.properties["POINT_SIZE"] = 50
out.properties["RESOLUTION_X"] = 100
out.properties["RESOLUTION_Y"] = 100
out.properties["SPACING"] = "C"
out.properties["AVERAGE_WIDTH"] = 60
out.properties["CHARSET_REGISTRY"] = "ISO8859"
out.properties["CHARSET_ENCODING"] = "1"
out.properties["COPYRIGHT"] = "MIT"
out.properties["CAP_HEIGHT"] = 7
out.properties["X_HEIGHT"] = 5
out.properties["WEIGHT"] = 10
out.properties["QUAD_WIDTH"] = 6
out.properties["FONT"] = "-" .. def(out.properties["FOUNDRY"])
                      .. "-" .. def(out.properties["FAMILY_NAME"])
                      .. "-" .. def(out.properties["WEIGHT_NAME"])
                      .. "-" .. def(out.properties["SLANT"])
                      .. "-" .. def(out.properties["SETWIDTH_NAME"])
                      .. "-" .. def(out.properties["ADD_STYLE"])
                      .. "-" .. def(out.properties["PIXEL_SIZE"])
                      .. "-" .. def(out.properties["POINT_SIZE"])
                      .. "-" .. def(out.properties["RESOLUTION_X"])
                      .. "-" .. def(out.properties["RESOLUTION_Y"])
                      .. "-" .. def(out.properties["SPACING"])
                      .. "-" .. def(out.properties["AVERAGE_WIDTH"])
                      .. "-" .. def(out.properties["CHARSET_REGISTRY"])
                      .. "-" .. def(out.properties["CHARSET_ENCODING"])
out.bdf_encodings = {}
for n=1,256 do
	out.bdf_encodings[n] = n-1
end
out.bdf_encodings.min_char_or_byte2 = 0
out.bdf_encodings.max_char_or_byte2 = 255
out.bdf_encodings.min_byte1 = 0
out.bdf_encodings.max_byte1 = 0
out.bdf_encodings.default_char = 0
out.glyph_names = {}
for n=1,256 do
	out.glyph_names[n] = string.format('U+%04X', n-1)
end
out.swidths = rep(def(out.properties["POINT_SIZE"], 100) * 4, 256)
-- Function for generating the glyphs
-- Note that this function checks for color index 1 in the bmp file rather than
--  a specific color.
-- This might mean that this function gives an incorrect result if the `*.bmp`
--  file is edited
out.bitmaps = function(self)
	local glyphs = {}
	for n=1,256 do
		local glyph = pcf.bitset(6*9)
		local i = 1
		local r = n-1
		-- We act as if there is a 1px border around each character (this isn't
		--  always the case, but it makes the font look better and it's easier
		--  than messing with the metrics)
		-- I believe that in ComputerCraft each glyph overlaps the previous one
		--  by one pixel.
		for y=2,10 do
			for x=2,7 do
				glyph[i] = d.data[1+(y-1)+11*((r // 16))][1+(x-1)+8*(r % 16)] == 1
				i = i + 1
			end
		end
		glyphs[n] = glyph
	end
	return glyphs
end
out.ink_metrics = calc_metrics(out.bitmaps(out),6,9,0,8)
out.accelerators.noOverlap       = 1
out.accelerators.constantMetrics = 1
out.accelerators.terminalFont    = 1
out.accelerators.constantWidth   = 1
out.accelerators.inkInside       = 1
out.accelerators.inkMetrics      = 1
out.accelerators.drawDirection   = 0
out.accelerators.realpadding     = 0
out.accelerators.fontAscent      = 8
out.accelerators.fontDescent     = 1
out.accelerators.maxOverlap      = 0
out.accelerators.minbounds = calc_bounds(out.metrics, math.min, 8)
out.accelerators.maxbounds = calc_bounds(out.metrics, math.max, 8)
out.accelerators.ink_minbounds = calc_bounds(out.ink_metrics, math.min, 8)
out.accelerators.ink_maxbounds = calc_bounds(out.ink_metrics, math.max, 8)
out.bdf_accelerators = out.accelerators

local f = assert(io.open('ccmono6x9r.pcf', 'wb'))
pcf.write(out, f)
f:close()

local out = pcf.create()
out.metrics = rep(
	{ left_sided_bearing   = 0
	, right_side_bearing   = 12
	, character_width      = 12
	, character_ascent     = 16
	, character_descent    = 2
	, character_attributes = 0
	}, 256)
out.properties["FONTNAME_REGISTRY"] = ""
out.properties["FOUNDRY"] = "Misc"
out.properties["FAMILY_NAME"] = "CCMono"
out.properties["WEIGHT_NAME"] = "Medium"
out.properties["SLANT"] = "R"
out.properties["SETWIDTH_NAME"] = "Normal"
out.properties["ADD_STYLE_NAME"] = ""
out.properties["PIXEL_SIZE"] = 20
out.properties["POINT_SIZE"] = 100
out.properties["RESOLUTION_X"] = 100
out.properties["RESOLUTION_Y"] = 100
out.properties["SPACING"] = "C"
out.properties["AVERAGE_WIDTH"] = 120
out.properties["CHARSET_REGISTRY"] = "ISO8859"
out.properties["CHARSET_ENCODING"] = "1"
out.properties["COPYRIGHT"] = "MIT"
out.properties["CAP_HEIGHT"] = 14
out.properties["X_HEIGHT"] = 10
out.properties["WEIGHT"] = 20
out.properties["QUAD_WIDTH"] = 12
out.properties["FONT"] = "-" .. def(out.properties["FOUNDRY"])
                      .. "-" .. def(out.properties["FAMILY_NAME"])
                      .. "-" .. def(out.properties["WEIGHT_NAME"])
                      .. "-" .. def(out.properties["SLANT"])
                      .. "-" .. def(out.properties["SETWIDTH_NAME"])
                      .. "-" .. def(out.properties["ADD_STYLE"])
                      .. "-" .. def(out.properties["PIXEL_SIZE"])
                      .. "-" .. def(out.properties["POINT_SIZE"])
                      .. "-" .. def(out.properties["RESOLUTION_X"])
                      .. "-" .. def(out.properties["RESOLUTION_Y"])
                      .. "-" .. def(out.properties["SPACING"])
                      .. "-" .. def(out.properties["AVERAGE_WIDTH"])
                      .. "-" .. def(out.properties["CHARSET_REGISTRY"])
                      .. "-" .. def(out.properties["CHARSET_ENCODING"])
out.bdf_encodings = {}
for n=1,256 do
	out.bdf_encodings[#out.bdf_encodings+1] = n-1
end
out.bdf_encodings.min_char_or_byte2 = 0
out.bdf_encodings.max_char_or_byte2 = 255
out.bdf_encodings.min_byte1 = 0
out.bdf_encodings.max_byte1 = 0
out.bdf_encodings.default_char = 0
out.glyph_names = {}
for n=1,256 do
	out.glyph_names[#out.glyph_names+1] = string.format('U+%04X', n-1)
end
out.swidths = rep(def(out.properties["POINT_SIZE"], 100) * 4, 256)
out.bitmaps = function(self)
	local glyphs = {}
	for n=1,256 do
		local glyph = pcf.bitset(12*18)
		local i = 1
		local r = n-1
		for y=2,10 do -- Act as if there is a 1px border around each character (even though this isn't always the case, it makes the font look better)
			for x=2,7 do
				glyph[i] = d.data[1+(y-1)+11*((r // 16))][1+(x-1)+8*(r % 16)] == 1
				i = i + 1
				glyph[i] = d.data[1+(y-1)+11*((r // 16))][1+(x-1)+8*(r % 16)] == 1
				i = i + 1
			end
			for n=1,12 do
				glyph[i] = glyph[i-12]
				i = i + 1
			end
		end
		glyphs[n] = glyph
	end
	return glyphs
end
out.ink_metrics = calc_metrics(out.bitmaps(out),6*2,9*2,0,8)
out.accelerators.noOverlap       = 1
out.accelerators.constantMetrics = 1
out.accelerators.terminalFont    = 1
out.accelerators.constantWidth   = 1
out.accelerators.inkInside       = 1
out.accelerators.inkMetrics      = 1
out.accelerators.drawDirection   = 0
out.accelerators.realpadding     = 0
out.accelerators.fontAscent      = 8*2
out.accelerators.fontDescent     = 1*2
out.accelerators.maxOverlap      = 0
out.accelerators.minbounds = calc_bounds(out.metrics, math.min, 8)
out.accelerators.maxbounds = calc_bounds(out.metrics, math.max, 8)
out.accelerators.ink_minbounds = calc_bounds(out.ink_metrics, math.min, 8)
out.accelerators.ink_maxbounds = calc_bounds(out.ink_metrics, math.max, 8)
out.bdf_accelerators = out.accelerators

local f = assert(io.open('ccmono12x18r.pcf', 'wb'))
pcf.write(out, f)
f:close()

local f = assert(io.open('./ccmono6x9r.pcf', 'rb'))
 -- Test if the `*.pcf` reader runs without crashing
 -- Uncomment the following lines for more information
local result = pcf.read(f)
-- io.write(pcf.show_metrics(result))
-- io.write(pcf.show_properties(result))
-- io.write(pcf.show_encodings(result))
-- io.write(pcf.show_glyph_names(result))
-- io.write(pcf.show_swidths(result))
-- io.write(pcf.show_accelerators(result))
-- io.write(pcf.show_glyphs(result, { chars_per_row = 16 }))
f:close()

