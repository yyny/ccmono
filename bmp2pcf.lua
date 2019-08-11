#!/usr/bin/env lua
local pcf = require "pcf"
local bmp = require "bmp"

local img, config

local function die(msg)
	print(msg)
	os.exit(1)
end
-- Repeat a value n times
local function rep(v, n)
	local result = {}
	for i=1,n do
		result[i] = v
	end
	return result
end
local function basename(path)
	return path:match("([^/]-)%.[^.]-$")
end
-- Function for generating the glyphs
-- (almost) black colors mark background, other colors mark foreground
local function bitmaps(self)
	local glyphs = {}
	for n=1,config.numglyphs do
		local glyph = pcf.bitset(config.scale*config.glyphwidth * config.scale*config.glyphheight)
		local i = 1
		local r = n-1
		for y=1,config.glyphheight do
			for o=1,config.scale do
				for x=1,config.glyphwidth do
					local val = img:get(x+(config.glyphwidth + config.padleft + config.padright)*(r % config.width) + config.padleft, y+(config.glyphheight + config.padtop + config.padbottom)*(r // config.width) + config.padtop)
					for p=1,config.scale do
						glyph[i] = val[1] >= 32 or val[2] >= 32 or val[3] >= 32
						i = i + 1
					end
				end
			end
		end
		glyphs[n] = glyph
	end
	return glyphs
end
local function glyphwidth(glyph)
	local first = glyph.height
	local last = 0
	for y=1,glyph.height do
		for x=1,glyph.width do
			if glyph.data[glyph.width*(y-1) + x] then
				first = math.min(first, x)
				last = math.max(last, x)
			end
		end
	end
	return math.max(last - first, 0)
end
local function glyphheight(glyph)
	local first = glyph.width
	local last = 0
	for x=1,glyph.width do
		for y=1,glyph.height do
			if glyph.data[glyph.width*(y-1) + x] then
				first = math.min(first, y)
				last = math.max(last, y)
			end
		end
	end
	return math.max(last - first + 1, 0)
end
local function printusage()
	print "Usage: bmp2pcf <infile> <outfile> [OPTIONS...]"
	print "Options:"
	print "  --width <N>           specify the number of glyphs per line   (default: 16 or ${imagewidth / glyphwidth})"
	print "  --height <N>          specify the number of lines with glyphs (default: 16 or ${imageheight / pixelsize})"
	print "  --glyphwidth <N>      specify the font glyph width            (default: ${imagewidth / width})"
	print "  --glyphheight <N>     specify the font glyph height           (default: ${pixelsize} or ${imageheight / height})"
	print "  --fontregistry <reg>  specify the font name registry          (default: '')"
	print "  --foundry <foundry>   specify the font foundry                (default: 'Misc')"
	print "  --family <family>     specify the font family                 (default: ${basename(infile)})"
	print "  --weight <weight>     specify the font weight name            (default: 'Medium')"
	print "  --weightnum <N>       specify the font weight number          (default: 10)"
	print "  --slant <slant>       specify the font slant                  (default: 'R')"
	print "  --setwidth <setwidth> specify the font setwidth               (default: 'Normal')"
	print "  --addstyle <style>    specify the font addstyle               (default: '')"
	print "  --pixelsize <px>      specify the font pixel size             (default: ${glyphheight} or ${imageheight / height})"
	print "  --pointsize <pt>      specify the font point size             (default: '100')"
	print "  --resx <pt>           specify the font horizontal resolution  (default: ${pointsize})"
	print "  --resx <pt>           specify the font vertical resolution    (default: ${pointsize})"
	print "  --spacing <spacing>   specify the font spacing                (default: 'C')"
	print "  --avgwidth <pt>       specify the font average width          (default: 60)"
	print "  --registry <name>     specify the font registry               (default: 'ISO8859')"
	print "  --encoding <encoding> specify the font encoding               (default: '1')"
	print "  --copyright <...>     specify the font copyright              (default: undefined)"
	print "  --comment <...>       specify the font comment                (default: undefined)"
	print "  --capheight <px>      specify the font uppercase letter size  (default: max height of A-Z)"
	print "  --xheight <px>        specify the font lowercase letter size  (default: height of x)"
	print "  --prop <name> <val>   specify the font custom property"
	print "  --numglyphs <N>       specify the number of glyphs            (default: ${width * height})"
	print "  --scale <N>           scale the font by N times               (default: '1')"
	print "  --padleft <px>        number of pixels left of each glyph     (default: '0')"
	print "  --padright <px>       number of pixels right of each glyph    (default: '0')"
	print "  --padtop <px>         number of pixels above of each glyph    (default: '0')"
	print "  --padbottom <px>      number of pixels under of each glyph    (default: '0')"
	os.exit(1)
end
local options = { 'width', 'height', 'quadwidth', 'glyphwidth', 'glyphheight',
				  'fontregistry', 'foundry', 'family', 'weight', 'weightnum',
	              'slant', 'setwidth', 'addstyle', 'pixelsize', 'pointsize',
	              'resx', 'resx', 'spacing', 'avgwidth', 'registry',
	              'encoding', 'copyright', 'comment', 'capheight', 'xheight',
	              'numglyphs', 'scale', 'padleft', 'padright', 'padtop', 'padbottom' }

if #arg < 2 then
	printusage()
end
local inpfile = arg[1]
local outfile = arg[2]
config = {}
config.properties = {}
local n = 3
while n < #arg do
	local valid = false
	for i=1,#options do
		local option = options[i]
		if arg[n] == '--' .. option then
			n = n + 1
			config[option] = arg[n]
			valid = true
		end
	end
	if arg[n] == '--quadwidth' then
		n = n + 1
		config['glyphwidth'] = arg[n]
		valid = true
	end
	if not valid then
		print("invalid option: " .. arg[n])
		printusage()
	end
	n = n + 1
end

local f = assert(io.open(inpfile, 'rb'))
img = assert(bmp.read(f))
f:close()

config.scale        = math.tointeger(config.scale) or 1
config.padleft      = math.tointeger(config.padleft) or 0
config.padright     = math.tointeger(config.padright) or 0
config.padtop       = math.tointeger(config.padtop) or 0
config.padbottom    = math.tointeger(config.padbottom) or 0

config.width        = math.tointeger(config.width) or config.glyphwidth and img.width // (config.glyphwidth + config.padleft + config.padright) or 16
config.height       = math.tointeger(config.height) or config.glyphheight and img.height // (config.glyphheight + config.padtop + config.padbottom) or 16
config.glyphwidth   = math.tointeger(config.glyphwidth) or img.width // config.width - config.padleft - config.padright
config.glyphheight  = math.tointeger(config.glyphheight) or config.pixelsize or img.height // config.height - config.padtop - config.padbottom
config.fontregistry = config.fontregistry or ''
config.foundry      = config.foundry or 'Misc'
config.family       = config.family or basename(inpfile) or die("specify a font family")
config.weight       = config.weight or 'Medium'
config.weightnum    = math.tointeger(config.weightnum) or 10
config.slant        = config.slant or 'R'
config.setwidth     = config.setwidth or 'Normal'
config.addstyle     = config.addstyle or ''
config.pixelsize    = math.tointeger(config.pixelsize) or config.glyphheight
config.pointsize    = math.tointeger(config.pointsize) or 100
config.resx         = math.tointeger(config.resx) or config.pointsize
config.resy         = math.tointeger(config.resy) or config.pointsize
config.spacing      = config.spacing or 'C'
config.avgwidth     = math.tointeger(config.avgwidth) or 100
config.registry     = config.registry or 'ISO8859'
config.encoding     = config.encoding or '1'
config.numglyphs    = math.tointeger(config.numglyphs) or config.width*config.height

if config.numglyphs > 256 then
	die("multi-byte encodings not yet supported")
end

local glyphs = bitmaps(nil)
local maxheight = 0
for n=string.byte('A'),string.byte('Z') do
	local glyph = glyphs[1+n]
	maxheight = math.max(maxheight, glyphheight({ width=config.glyphwidth, height=config.glyphheight, data = glyph }))
end
config.capheight    = config.capheight or maxheight
config.xheight      = config.xheight or glyphheight({ width=config.glyphwidth, height=config.glyphheight, data = glyphs[1+string.byte('x')] })

-- Display the bitmap with a nice border around it
if true then
	io.write('+',string.rep('-', img.width),'+','\n')
	for y=1,img.height do
		io.write('|')
		for x=1,img.width do
			local val = img:get(x, y)
			io.write(val[1] <= 64 and val[2] <= 64 and val[3] <= 64 and '.' or '#')
		end
		io.write('|\n')
	end
	io.write('+',string.rep('-',img.width),'+','\n')
end

-- Function for calculating metrics of each glyph
-- lsb = max left sided bearing (0 for terminal fonts)
-- rsb = max right sided bearing
local function calc_metrics(glyphs,w,h,lsb,rsb)
	local result = {}
	for n=1,#glyphs do
		local glyph = glyphs[n]
		----------------------------------------------------------------------
		local left_side_bearing = 0
		for x=1,lsb do
			local done = false
			for y=1,h do
				if glyph[(y-1)*h+x] then
					done = true
					break
				end
			end
			if done then break end
			left_side_bearing = left_side_bearing + 1
		end
		----------------------------------------------------------------------
		local right_side_bearing = 0
		for x=1,rsb do
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
		----------------------------------------------------------------------
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
		----------------------------------------------------------------------
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
		----------------------------------------------------------------------
		result[n] =
			{ left_side_bearing    = left_side_bearing
			, right_side_bearing   = w - right_side_bearing
			, character_width      = w
			, character_ascent     = (h - 2) - character_ascent -- FIXME: Magic number 2 = offset from bottom of font baseline
			, character_descent    = 2 - character_descent
			, character_attributes = 0
			}
	end
	return result
end
-- Function for calculating metric bounds according to function `f` (which should be math.min or math.max)
local function calc_bounds(metrics, f, w)
	local keys = {'left_side_bearing', 'right_side_bearing', 'character_width', 'character_ascent', 'character_descent', 'character_attributes'}
	local r = {}
	for n=1,#metrics do
		for i=1,#keys do
			local key = keys[i]
			r[key] = f(metrics[n][key], r[key] or metrics[n][key])
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
	{ left_side_bearing    = 0
	, right_side_bearing   = config.scale * config.glyphwidth
	, character_width      = config.scale * config.glyphwidth
	, character_ascent     = config.scale * (config.glyphheight - 1)
	, character_descent    = config.scale * 1
	, character_attributes = 0
	}, config.numglyphs)
out.properties["FONTNAME_REGISTRY"] = config.fontregistry
out.properties["FOUNDRY"] = config.foundry
out.properties["FAMILY_NAME"] = config.family
out.properties["WEIGHT_NAME"] = config.weight
out.properties["SLANT"] = config.slant
out.properties["SETWIDTH_NAME"] = config.setwidth
out.properties["ADD_STYLE_NAME"] = config.addstyle
out.properties["PIXEL_SIZE"] = config.scale * math.tointeger(config.pixelsize)
out.properties["POINT_SIZE"] = math.tointeger(config.pointsize)
out.properties["RESOLUTION_X"] = math.tointeger(config.resx)
out.properties["RESOLUTION_Y"] = math.tointeger(config.resy)
out.properties["SPACING"] = config.spacing
out.properties["AVERAGE_WIDTH"] = config.scale * math.tointeger(config.avgwidth)
out.properties["CHARSET_REGISTRY"] = config.registry
out.properties["CHARSET_ENCODING"] = config.encoding
if config.copyright then
	out.properties["COPYRIGHT"] = config.copyright
end
if config.comment then
	out.properties["NOTICE"] = config.comment
end
out.properties["CAP_HEIGHT"] = config.scale * math.tointeger(config.capheight)
out.properties["X_HEIGHT"] = config.scale * math.tointeger(config.xheight)
out.properties["WEIGHT"] = math.tointeger(config.weightnum)
out.properties["QUAD_WIDTH"] = config.scale * math.tointeger(config.glyphwidth)
out.properties["FONT"] = def(out.properties["FONTNAME_REGISTRY"])
               .. "-" .. def(out.properties["FOUNDRY"])
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
for n=1,config.numglyphs do
	out.bdf_encodings[n] = n-1
end
out.bdf_encodings.min_char_or_byte2 = 0
out.bdf_encodings.max_char_or_byte2 = config.numglyphs - 1
out.bdf_encodings.min_byte1 = 0
out.bdf_encodings.max_byte1 = 0
out.bdf_encodings.default_char = 0
out.glyph_names = {}
for n=1,config.numglyphs do
	out.glyph_names[n] = string.format('U+%04X', n-1)
end
out.swidths = rep(config.scale * (def(out.properties["POINT_SIZE"], 100) * config.glyphwidth / 10) * 4, config.numglyphs)
out.bitmaps = bitmaps
out.ink_metrics = calc_metrics(out.bitmaps(out),config.scale * config.glyphwidth,config.scale * config.glyphheight,0,config.scale * config.glyphwidth)
out.accelerators.noOverlap       = 1
out.accelerators.constantMetrics = 1
out.accelerators.terminalFont    = 1
out.accelerators.constantWidth   = 1
out.accelerators.inkInside       = 1
out.accelerators.inkMetrics      = 1
out.accelerators.drawDirection   = 0
out.accelerators.realpadding     = 0
out.accelerators.fontAscent      = config.scale * (config.glyphheight - 1)
out.accelerators.fontDescent     = config.scale * 1
out.accelerators.maxOverlap      = 0
out.accelerators.minbounds       = calc_bounds(out.metrics, math.min, 8)
out.accelerators.maxbounds       = calc_bounds(out.metrics, math.max, 8)
out.accelerators.ink_minbounds   = calc_bounds(out.ink_metrics, math.min, 8)
out.accelerators.ink_maxbounds   = calc_bounds(out.ink_metrics, math.max, 8)
out.bdf_accelerators = out.accelerators

local f = assert(io.open(outfile, 'wb'))
pcf.write(out, f)
f:close()
