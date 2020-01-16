#!/usr/bin/env lua
local bitset = require "bitset"
local asciigrid = require "asciigrid"

-- Library for reading and writing PCF fonts
-- It is specifically tested for reading and writing the ccmono fonts, but
--  probably work fine for other `.pcf` fonts aswell.
-- Based on https://fontforge.github.io/pcf-format.html
local PCF_PROPERTIES       = (1<<0)
local PCF_ACCELERATORS     = (1<<1)
local PCF_METRICS          = (1<<2)
local PCF_BITMAPS          = (1<<3)
local PCF_INK_METRICS      = (1<<4)
local PCF_BDF_ENCODINGS    = (1<<5)
local PCF_SWIDTHS          = (1<<6)
local PCF_GLYPH_NAMES      = (1<<7)
local PCF_BDF_ACCELERATORS = (1<<8)

local PCF_FORMAT_MASK        = 0xffffff00
local PCF_DEFAULT_FORMAT     = 0x00000000
local PCF_INKBOUNDS          = 0x00000200
local PCF_ACCEL_W_INKBOUNDS  = 0x00000100
local PCF_COMPRESSED_METRICS = 0x00000100

local PCF_GLYPH_PAD_MASK  = (3<<0) -- See the bitmap table for explanation
local PCF_BYTE_MASK       = (1<<2) -- If set then Most Sig Byte First
local PCF_BIT_MASK        = (1<<3) -- If set then Most Sig Bit First
local PCF_SCAN_UNIT_MASK  = (3<<4) -- See the bitmap table for explanation

local function PCF_SIZE_TO_INDEX(s)
	if s == 4 then
		return 2
	elseif s == 2 then
		return 1
	else
		return 0
	end
end
local function PCF_INDEX_TO_SIZE(b)
	return 1 << b
end

local function PCF_FORMAT(msbitfirst, msbytefirst, glyph, scan)
    return (PCF_SIZE_TO_INDEX(scan) << 4)
         | ((msbitfirst and 1 or 0) << 3)
         | ((msbytefirst and 1 or 0) << 2)
    	 | (PCF_SIZE_TO_INDEX(glyph) << 0)
end

local tables = {"properties", "accelerators", "metrics", "bitmaps", "ink_metrics", "bdf_encodings", "swidths", "glyph_names", "bdf_accelerators"}

local tablenames = {
	["properties"]         = PCF_PROPERTIES,
	["accelerators"]       = PCF_ACCELERATORS,
	["metrics"]            = PCF_METRICS,
	["bitmaps"]            = PCF_BITMAPS,
	["ink_metrics"]        = PCF_INK_METRICS,
	["bdf_encodings"]      = PCF_BDF_ENCODINGS,
	["swidths"]            = PCF_SWIDTHS,
	["glyph_names"]        = PCF_GLYPH_NAMES,
	["bdf_accelerators"]   = PCF_BDF_ACCELERATORS,

	[PCF_PROPERTIES]       = "properties",
	[PCF_ACCELERATORS]     = "accelerators",
	[PCF_METRICS]          = "metrics",
	[PCF_BITMAPS]          = "bitmaps",
	[PCF_INK_METRICS]      = "ink_metrics",
	[PCF_BDF_ENCODINGS]    = "bdf_encodings",
	[PCF_SWIDTHS]          = "swidths",
	[PCF_GLYPH_NAMES]      = "glyph_names",
	[PCF_BDF_ACCELERATORS] = "bdf_accelerators",
}
local formats = {"B","I2","I4","I8"}

local function write(f, fmt, ...)
	local res = string.pack(fmt, ...)
	f:write(res)
end
local function pad(f,by) by = by or 4
	local pos = f:seek()
	local padding = pos % by == 0 and 0 or (by - (pos % by))
	f:write(string.rep('\0', padding))
	return padding
end

local pcf = {}
pcf.tables = tables
pcf.bitset = bitset
function pcf.tablename(table)
	return tablenames[table.type]
end
function pcf.parseformat(format)
	local result = {}
	result.format        = format
	result.endian        = format & 4 ~= 0 and '>' or '<'
	result.bitord        = format & 8 ~= 0 and '>' or '<'
	result.paddingtype   = 1 + format & 3
	result.storetype     = 1 + (format >> 4) & 3
	result.padding       = 1 << (format & 3)
	result.storesize     = 1 << ((format >> 4) & 3)
	result.paddingformat = formats[result.paddingtype]
	result.storeformat   = formats[result.storetype]
	return result
end
function pcf.readformat(f)
	local format = string.unpack('<i4', f:read(4))
	return pcf.parseformat(format)
end
function pcf.readmetrics(f, format, compressed)
	if compressed == nil then
		compressed = format.format & PCF_COMPRESSED_METRICS ~= 0
	end
	local left_side_bearing, right_side_bearing, character_width, character_ascent, character_descent, character_attributes
	character_attributes = 0
	if compressed then
		left_side_bearing, right_side_bearing, character_width, character_ascent, character_descent = string.unpack("BBBBB", f:read(5))
		left_side_bearing = left_side_bearing - 0x80
		right_side_bearing = right_side_bearing - 0x80
		character_width = character_width - 0x80
		character_ascent = character_ascent - 0x80
		character_descent = character_descent - 0x80
	else
		left_side_bearing, right_side_bearing, character_width, character_ascent, character_descent, character_attributes = string.unpack(format.endian .. "i2i2i2i2i2I2", f:read(12))
	end
	return { left_side_bearing=left_side_bearing, right_side_bearing=right_side_bearing, character_width=character_width, character_ascent=character_ascent, character_descent=character_descent, character_attributes=character_attributes }
end
function pcf.writemetrics(self, data, f, format, compress)
	local fmt = pcf.parseformat(format)
	if compress == nil then
		compress = format & PCF_COMPRESSED_METRICS ~= 0
	end
	if compress then
		write(f, fmt.endian .. 'B', 0x80 + data.left_side_bearing)
		write(f, fmt.endian .. 'B', 0x80 + data.right_side_bearing)
		write(f, fmt.endian .. 'B', 0x80 + data.character_width)
		write(f, fmt.endian .. 'B', 0x80 + data.character_ascent)
		write(f, fmt.endian .. 'B', 0x80 + data.character_descent)
		return 5
	else
		write(f, fmt.endian .. 'i2', data.left_side_bearing)
		write(f, fmt.endian .. 'i2', data.right_side_bearing)
		write(f, fmt.endian .. 'i2', data.character_width)
		write(f, fmt.endian .. 'i2', data.character_ascent)
		write(f, fmt.endian .. 'i2', data.character_descent)
		write(f, fmt.endian .. 'I2', data.character_attributes)
		return 6*2
	end
end
function pcf.show_metric_bounds(bounds)
	return table.concat
		{ '{ '
		, 'left_side_bearing: ', bounds.left_side_bearing, ', '
		, 'right_side_bearing: ', bounds.right_side_bearing, ', '
		, 'character_width: ', bounds.character_width, ', '
		, 'character_ascent: ', bounds.character_ascent, ', '
		, 'character_descent: ', bounds.character_descent, ', '
		, 'character_attributes: ', bounds.character_attributes, ' }'
		}
end

function pcf.read(f)
	local data = pcf.create()
	local header, err = pcf.readheader(f)
	if not header then return nil, err end
	for _,table in ipairs(header.tables) do
		pcf.readtable(f, table, data)
	end
	data.header = header
	return data
end

function pcf.write(data, f)
	local offs = {}
	local sizes = {}
	local formats = {}

	f:write('\1fcp')
	write(f, '<i4', #tables)
	for n=1,#tables do
		write(f, '<i4', tablenames[tables[n]])
		write(f, '<i4', 0)
		write(f, '<i4', 0)
		write(f, '<i4', 0)
	end
	local format = PCF_FORMAT(true, true, 4, 0)
	for n=1,#tables do
		local t = tables[n]
		offs[n] = f:seek()
		sizes[n], formats[n] = pcf.tablewriters[t](data, f, data[t], format)
		sizes[n] = sizes[n] + pad(f)
		sizes[n] = f:seek() - offs[n]
	end
	for n=1,#sizes do
		f:seek('set', 8+16*(n-1)+4)
		write(f, '<i4', formats[n])
		write(f, '<i4', sizes[n])
		write(f, '<i4', offs[n])
	end
end
function pcf.readheader(f)
	local header = {}
	local magic, table_count = string.unpack('<c4i4', f:read(8))
	if magic ~= '\1fcp' then return nil, 'invalid signiature' end
	local tables = {}
	for n=1,table_count do
		local type, format, size, offset = string.unpack('<i4i4i4i4', f:read(16))
		local table = { type=type, format=format, size=size, offset=offset }
		tables[#tables+1] = table
		tables[tablenames[type]] = table
	end
	header.tables = tables
	return header
end
function pcf.readtable(f, table, data)
	local name = pcf.tablename(table)
	local before = f:seek()
	f:seek('set', table.offset)
	local from = f:seek()
	data[name] = pcf.tablereaders[name](table, f)
	local to = f:seek()
end

function pcf.show_metrics(data)
	local function metrics_to_rows()
		local result = {}
		for n, metric in ipairs(data.metrics) do
			local repr = utf8.char(n-1)
			if n-1 < 32 or n-1 >= 127 and n-1 <= 159 then
				repr = "\\x" .. ("%.2x"):format(n-1)
			end
			result[#result + 1] = { "'" .. repr .. "'", "(" .. tonumber(n-1) .. ")", metric.left_side_bearing, metric.right_side_bearing, metric.character_width, metric.character_ascent, metric.character_descent, metric.character_attributes }
		end
		return result
	end
	local result = ''
	local grid = assert(asciigrid({
		title = 'normal metrics',
		header_type = 'arrows',
		column_justify = { 'center', 'right' },
		column_headers = { 'character representation',
			               'character code',
						   'left side bearing',
						   'right side bearing',
						   'character width',
						   'character ascent',
						   'character descent',
						   'character attributes' },
		rows = metrics_to_rows(data.metrics),
		callbacks = { string_length = utf8.len }
	}))
	result = result .. table.concat(grid.lines, '\n') .. '\n'
	local grid = assert(asciigrid({
		title = 'ink metrics',
		header_type = 'arrows',
		column_justify = { 'center', 'right' },
		column_headers = { 'character representation',
			               'character code',
						   'left side bearing',
						   'right side bearing',
						   'character width',
						   'character ascent',
						   'character descent',
						   'character attributes' },
		rows = metrics_to_rows(data.metrics),
		callbacks = { string_length = utf8.len }
	}))
	result = result .. table.concat(grid.lines, '\n') .. '\n'
	return result
end
function pcf.show_encodings(data)
	local result = {}
	for n=1,#data.bdf_encodings do
		result[#result+1] = data.bdf_encodings[n]
		result[#result+1] = n == #data.bdf_encodings and '' or ","
	end
	result[#result+1] = '\n'
	return table.concat(result)
end
function pcf.show_properties(data)
	local result = {}
	for n=1,#data.properties do
		local property = data.properties[n]
		if type(property.value) ~= 'number' then
			result[#result+1] = property.name .. ' = "' .. tostring(property.value) .. '";\n'
		else
			result[#result+1] = property.name .. ' = ' .. property.value .. ';\n'
		end
	end
	return table.concat(result)
end
function pcf.show_glyph_names(data)
	local result = {}
	for n=1,#data.glyph_names do
		result[#result+1] = data.glyph_names[n]
		result[#result+1] = n == #data.glyph_names and '' or ","
	end
	result[#result+1] = '\n'
	return table.concat(result)
end
function pcf.show_swidths(data)
	local result = {}
	for n=1,#data.swidths do
		result[#result+1] = data.swidths[n]
		result[#result+1] = n == #data.swidths and '' or ","
	end
	result[#result+1] = '\n'
	return table.concat(result)
end
function pcf.show_glyphs(data, options)
	local result = {}
	options = options or {}
	local borders = options.borders or true
	local charset = options.charset or '.#'
	local w = options.width or data.properties["QUAD_WIDTH"]
	local h = options.height or data.properties["PIXEL_SIZE"]
	local chars_per_row = options.chars_per_row or 8
	local n = 0
	local bitmaps = data.bitmaps(data)
	if borders then
		if #bitmaps ~= 0 then
			result[#result+1] = string.rep('+' .. string.rep('-', w), chars_per_row) .. '+'
		end
	end
	while n < #bitmaps-1 do
		local lines = {}
		for n=1,h do
			lines[n] = borders and '|' or ''
		end
		for m=1,chars_per_row do
			if not bitmaps[n+m] then break end
			local linen = 1
			for line in bitmaps[n+m]:tostring(charset):gmatch(string.rep('.', w)) do
				lines[linen] = lines[linen] .. line .. (borders and '|' or '')
				if linen == h then break end
				linen = linen + 1
			end
		end
		for n=1,#lines do
			result[#result+1] = lines[n]
		end
		if borders then
			result[#result+1] = string.rep('+' .. string.rep('-', w), (#lines ~= 0 and #lines[1] or 0) // (w+1)) .. '+'
		end
		n = n + chars_per_row
	end
	result[#result+1] = ''
	return table.concat(result, '\n')
end
function pcf.show_accelerators(result)
	return table.concat
		{ 'accelerators:\n'
		, 'noOverlap:       ', result.accelerators.noOverlap, '\n'
		, 'constantMetrics: ', result.accelerators.constantMetrics, '\n'
		, 'terminalFont:    ', result.accelerators.terminalFont, '\n'
		, 'constantWidth:   ', result.accelerators.constantWidth, '\n'
		, 'inkInside:       ', result.accelerators.inkInside, '\n'
		, 'inkMetrics:      ', result.accelerators.inkMetrics, '\n'
		, 'drawDirection:   ', result.accelerators.drawDirection, '\n'
		, 'realpadding:     ', result.accelerators.realpadding, '\n'
		, 'fontAscent:      ', result.accelerators.fontAscent, '\n'
		, 'fontDescent:     ', result.accelerators.fontDescent, '\n'
		, 'maxOverlap:      ', result.accelerators.maxOverlap, '\n'
		, 'minbounds:       ', pcf.show_metric_bounds(result.accelerators.minbounds), '\n'
		, 'maxbounds:       ', pcf.show_metric_bounds(result.accelerators.maxbounds), '\n'
		, 'ink_minbounds:   ', pcf.show_metric_bounds(result.accelerators.ink_minbounds), '\n'
		, 'ink_maxbounds:   ', pcf.show_metric_bounds(result.accelerators.ink_maxbounds), '\n'
		, 'bdf_accelerators:\n'
		, 'noOverlap:       ', result.bdf_accelerators.noOverlap, '\n'
		, 'constantMetrics: ', result.bdf_accelerators.constantMetrics, '\n'
		, 'terminalFont:    ', result.bdf_accelerators.terminalFont, '\n'
		, 'constantWidth:   ', result.bdf_accelerators.constantWidth, '\n'
		, 'inkInside:       ', result.bdf_accelerators.inkInside, '\n'
		, 'inkMetrics:      ', result.bdf_accelerators.inkMetrics, '\n'
		, 'drawDirection:   ', result.bdf_accelerators.drawDirection, '\n'
		, 'realpadding:     ', result.bdf_accelerators.realpadding, '\n'
		, 'fontAscent:      ', result.bdf_accelerators.fontAscent, '\n'
		, 'fontDescent:     ', result.bdf_accelerators.fontDescent, '\n'
		, 'maxOverlap:      ', result.bdf_accelerators.maxOverlap, '\n'
		, 'minbounds:       ', pcf.show_metric_bounds(result.bdf_accelerators.minbounds), '\n'
		, 'maxbounds:       ', pcf.show_metric_bounds(result.bdf_accelerators.maxbounds), '\n'
		, 'ink_minbounds:   ', pcf.show_metric_bounds(result.bdf_accelerators.ink_minbounds), '\n'
		, 'ink_maxbounds:   ', pcf.show_metric_bounds(result.bdf_accelerators.ink_maxbounds), '\n'
		}
end
function pcf.create()
	local result = {}
	result.properties = {}
	result.accelerators = {}
	result.metrics = {}
	result.bitmaps = function() return {} end
	result.ink_metrics = {}
	result.bdf_encodings = {}
	result.swidths = {}
	result.glyph_names = {}
	result.bdf_accelerators = {}
	setmetatable(result.properties, {
		__newindex = function(self,key,value)
			local idx = #self+1
			rawset(self, idx, { index=idx, name=key, value=value })
			rawset(self, key, { index=idx, name=key, value=value })
		end
	})
	return result
end

pcf.tablewriters = {}
function pcf.tablewriters.properties(self, f, data, format)
	write(f, '<i4', format)
	local fmt = pcf.parseformat(format)
	write(f, fmt.endian .. 'i4', #data)
	local fmt = pcf.parseformat(format)
	local s = ''
	local nameoffs = {}
	local valueoffs = {}
	for n=1,#data do
		local value = data[n].value
		nameoffs[n] = #s
		s = s .. data[n].name .. '\0'
		if type(value) == 'string' then
			valueoffs[n] = #s
			s = s .. data[n].value .. '\0'
		end
	end
	for n=1,#data do
		local value = data[n].value
		if type(value) == 'string' then
			write(f, fmt.endian .. 'i4bi4', nameoffs[n], 1, valueoffs[n])
		elseif type(value) == 'number' then
			write(f, fmt.endian .. 'i4bi4', nameoffs[n], 0, value)
		else
			error('property "' .. data[n].name .. '" is neither a string nor a number')
		end
	end
	local padding = pad(f)
	write(f, fmt.endian .. 'i4', #s)
	f:write(s)
	return 3*4 + (4 + 1 + 4) * #data + #s + padding, format
end
function pcf.tablewriters.accelerators(self, f, data, format)
	format = format | PCF_ACCEL_W_INKBOUNDS
	write(f, '<i4', format)
	local fmt = pcf.parseformat(format)
	write(f, fmt.endian .. 'B', data.noOverlap)
	write(f, fmt.endian .. 'B', data.constantMetrics)
	write(f, fmt.endian .. 'B', data.terminalFont)
	write(f, fmt.endian .. 'B', data.constantWidth)
	write(f, fmt.endian .. 'B', data.inkInside)
	write(f, fmt.endian .. 'B', data.inkMetrics)
	write(f, fmt.endian .. 'B', data.drawDirection)
	write(f, fmt.endian .. 'B', data.realpadding)
	write(f, fmt.endian .. 'i4', data.fontAscent)
	write(f, fmt.endian .. 'i4', data.fontDescent)
	write(f, fmt.endian .. 'i4', data.maxOverlap)
	local metrics_size = pcf.writemetrics(self, data.minbounds, f, format, false)
	pcf.writemetrics(self, data.maxbounds, f, format, false)
	if format & PCF_ACCEL_W_INKBOUNDS ~= 0 then
		pcf.writemetrics(self, data.ink_minbounds, f, format, false)
		pcf.writemetrics(self, data.ink_maxbounds, f, format, false)
	end
	return 4*4 + 8 + metrics_size*4, format
end
function pcf.tablewriters.metrics(self, f, data, format)
	format = format | PCF_COMPRESSED_METRICS
	write(f, '<i4', format)
	local compressed = format & PCF_COMPRESSED_METRICS ~= 0
	local fmt = pcf.parseformat(format)
	write(f, fmt.endian .. 'i' .. (compressed and '2' or '4'), #data)
	local metrics_size
	for n=1,#data do
		metrics_size = pcf.writemetrics(self, data[n], f, format, compressed)
	end
	return 1*4 + (compress and 2 or 4) + metrics_size * #data, format
end
local function reverse_bits(a)
	return ((a & 0x1)  << 7) | ((a & 0x2)  << 5) |
	       ((a & 0x4)  << 3) | ((a & 0x8)  << 1) |
	       ((a & 0x10) >> 1) | ((a & 0x20) >> 3) |
	       ((a & 0x40) >> 5) | ((a & 0x80) >> 7);
end
local function bin(x)
	local s = ''
	s = s .. ((x & 0x01 == 0) and '0' or '1')
	s = s .. ((x & 0x02 == 0) and '0' or '1')
	s = s .. ((x & 0x04 == 0) and '0' or '1')
	s = s .. ((x & 0x08 == 0) and '0' or '1')
	s = s .. ((x & 0x10 == 0) and '0' or '1')
	s = s .. ((x & 0x20 == 0) and '0' or '1')
	s = s .. ((x & 0x40 == 0) and '0' or '1')
	s = s .. ((x & 0x80 == 0) and '0' or '1')
	return s
end

function pcf.tablewriters.bitmaps(self, f, data, format)
	data = data(self)
	write(f, '<i4', format)
	local fmt = pcf.parseformat(format)
	write(f, fmt.endian .. 'i4', #data)
	local offsets = {}
	local s = ''
	local w = self.properties["QUAD_WIDTH"].value
	local h = self.properties["PIXEL_SIZE"].value
	local glyphsize = math.ceil((w*h)/8)
	for n=1,#data do
		offsets[n] = #s
		for y=1,h do
			local byte = 0
			local bits_written = 0
			local bytes_written = 0
			for x=1,w do
				byte = byte | ((data[n][(y-1)*w+x] and 1 or 0) << (7-bits_written))
				bits_written = bits_written + 1
				if bits_written == 8 then
					s = s .. string.pack('B', byte)
					byte = 0
					bits_written = 0
					bytes_written = bytes_written + 1
				end
			end
			if bits_written ~= 0 then
				s = s .. string.pack('B', byte)
				bytes_written = bytes_written + 1
			end
			for n=1,(4-bytes_written) % 4 do
				s = s .. '\0'
			end
		end
	end
	for n=1,#offsets do
		write(f, fmt.endian .. 'i4', offsets[n])
	end
	write(f, fmt.endian .. 'i4', #s)
	write(f, fmt.endian .. 'i4', #s)
	write(f, fmt.endian .. 'i4', #s)
	write(f, fmt.endian .. 'i4', #s)
	f:write(s)
	return 6*4 + 4 * #offsets + #s, format
end
function pcf.tablewriters.swidths(self, f, data, format)
	write(f, '<i4', format)
	local fmt = pcf.parseformat(format)
	write(f, fmt.endian .. 'i4', #data)
	for n=1,#data do
		write(f, fmt.endian .. 'i4', data[n])
	end
	return 2*4 + 4 * #data, format
end
function pcf.tablewriters.encodings(self, f, data, format)
	write(f, '<i4', format)
	local fmt = pcf.parseformat(format)
	write(f, fmt.endian .. 'i2', data.min_char_or_byte2)
	write(f, fmt.endian .. 'i2', data.max_char_or_byte2)
	write(f, fmt.endian .. 'i2', data.min_byte1)
	write(f, fmt.endian .. 'i2', data.max_byte1)
	write(f, fmt.endian .. 'i2', data.default_char)
	for n=1,#data do
		write(f, fmt.endian .. 'i2', data[n])
	end
	return 4 + 5 * 2 + 2 * #data, format
end
function pcf.tablewriters.glyph_names(self, f, data, format)
	write(f, '<i4', format)
	local fmt = pcf.parseformat(format)
	write(f, fmt.endian .. 'i4', #data)
	local offsets = {}
	local s = ''
	for n=1,#data do
		offsets[n] = #s
		s = s .. data[n] .. '\0'
	end
	for n=1,#offsets do
		write(f, fmt.endian .. 'i4', offsets[n])
	end
	write(f, fmt.endian .. 'i4', #s)
	f:write(s)
	return 4*3 + 4 * #offsets + #s, format
end
pcf.tablewriters.ink_metrics = pcf.tablewriters.metrics
pcf.tablewriters.bdf_encodings = pcf.tablewriters.encodings
pcf.tablewriters.bdf_accelerators = pcf.tablewriters.accelerators

pcf.tablereaders = {}
function pcf.tablereaders.properties(self, f)
	local format = pcf.readformat(f)
	local nprops = string.unpack(format.endian .. 'i4', f:read(4))
	local properties = {}
	for n=1,nprops do
		local name_off, isstr, value_off = string.unpack(format.endian .. 'i4bi4', f:read(9))
		table.insert(properties, {name_off=name_off, value_off=value_off, isstr=isstr == 1})
	end
	f:read((nprops&3)==0 and 0 or(4-(nprops&3)))
	local strings_size = string.unpack(format.endian .. 'i', f:read(4))
	local strings = f:read(strings_size)
	for n=1,nprops do
		local property = properties[n]
		local name = string.match(strings, "[^\0]*", property.name_off+1)
		local value = property.isstr and string.match(strings, "[^\0]*", property.value_off+1) or property.value_off
		if not name or not value then
			error('too few properties (' .. nprops .. ' expected, got ' .. n-1 .. ')')
		end
		property.index = n
		property.name = name
		property.value = value
		properties[name] = value
	end
	return properties
end
function pcf.tablereaders.accelerators(self, f)
	local format = pcf.readformat(f)
	local noOverlap, constantMetrics, terminalFont, constantWidth, inkInside, inkMetrics, drawDirection, realpadding = string.unpack('BBBBBBBB', f:read(8))
	local fontAscent, fontDescent, maxOverlap = string.unpack(format.endian .. 'i4i4i4', f:read(12))
	local minbounds, maxbounds, ink_minbounds, ink_maxbounds
	minbounds, maxbounds = pcf.readmetrics(f, format, false), pcf.readmetrics(f, format, false)
	if format.format & PCF_ACCEL_W_INKBOUNDS ~= 0 then
		ink_minbounds = pcf.readmetrics(f, format, false)
		ink_maxbounds = pcf.readmetrics(f, format, false)
	else
		ink_minbounds = minbounds
		ink_maxbounds = maxbounds
	end
	local result = {}
	result.noOverlap       = noOverlap
	result.constantMetrics = constantMetrics
	result.terminalFont    = terminalFont
	result.constantWidth   = constantWidth
	result.inkInside       = inkInside
	result.inkMetrics      = inkMetrics
	result.drawDirection   = drawDirection
	result.realpadding     = realpadding
	result.fontAscent      = fontAscent
	result.fontDescent     = fontDescent
	result.maxOverlap      = maxOverlap
	result.minbounds       = minbounds
	result.maxbounds       = maxbounds
	result.ink_minbounds   = ink_minbounds
	result.ink_maxbounds   = ink_maxbounds
	return result
end
function pcf.tablereaders.metrics(self, f)
	local format = pcf.readformat(f)
	compressed = format.format & PCF_COMPRESSED_METRICS ~= 0
	local count = string.unpack(format.endian .. 'i' .. (compressed and '2' or '4'), f:read(compressed and 2 or 4))
	local result = {}
	for n=1,count do
		result[#result+1] = pcf.readmetrics(f, format)
	end
	return result
end
function pcf.tablereaders.bitmaps(self, f)
	local format = pcf.readformat(f)
	local glyph_count = string.unpack(format.endian .. 'i4', f:read(4))
	local glyph_offsets = {}
	for n=1,glyph_count do
		local offset = string.unpack(format.endian .. 'i4', f:read(4))
		glyph_offsets[n] = offset
	end
	local bitmapsizes = {string.unpack(format.endian .. 'i4i4i4i4', f:read(16))}
	local bitmap_data  = f:read(bitmapsizes[format.paddingtype])
	return function(self)
		local glyphs = {}
		local function tobitset(s,storesize,padding,w,h)
			local result = pcf.bitset(w*h)
			local bytes_per_row = math.ceil(w * storesize / 8)
			local bytes = {string.unpack(string.rep(string.rep('B', bytes_per_row) .. string.rep('x', padding-bytes_per_row), #s/math.max(padding, bytes_per_row)), s)}
			local n = 1
			while n < #bytes do
				local bits = 0
				while bits < w do
					local byte = bytes[n]
					for m=0,7 do
						local q = (format.bitord == '>') and (7-m) or m
						local bit = byte & (1 << q) ~= 0
						result[((n-1)//bytes_per_row)*w+bits+1] = bit
						bits = bits + 1
					end
					n = n + 1
				end
			end
			return result
		end
		local w = self.properties["QUAD_WIDTH"]
		local h = self.properties["PIXEL_SIZE"]
		for x=1,glyph_count do
			local glyph_data_size = math.max(format.padding, format.storesize)*h
			local glyph_data = bitmap_data:sub(glyph_offsets[x]+1,glyph_offsets[x]+glyph_data_size)
			table.insert(glyphs, tobitset(glyph_data,format.storesize,format.padding,w,h))
		end
		return glyphs
	end
end
function pcf.tablereaders.swidths(self, f)
	local format = pcf.readformat(f)
	local glyph_count = string.unpack(format.endian .. 'i4', f:read(4))
	local swidths = {}
	for n=1,glyph_count do
		local swidth = string.unpack(format.endian .. 'i4', f:read(4))
		swidths[n] = swidth
	end
	return swidths
end
function pcf.tablereaders.encodings(self, f)
	local format = pcf.readformat(f)
	local min_char_or_byte2 = string.unpack(format.endian .. 'i2', f:read(2))
	local max_char_or_byte2 = string.unpack(format.endian .. 'i2', f:read(2))
	local min_byte1 = string.unpack(format.endian .. 'i2', f:read(2))
	local max_byte1 = string.unpack(format.endian .. 'i2', f:read(2))
	local default_char = string.unpack(format.endian .. 'i2', f:read(2))
	local nenc = (max_char_or_byte2-min_char_or_byte2+1)*(max_byte1-min_byte1+1)
	local glyph_indices = {}
	for n=1,nenc do
		glyph_indices[n] = string.unpack(format.endian .. 'i2', f:read(2))
	end
	glyph_indices.min_char_or_byte2 = min_char_or_byte2
	glyph_indices.max_char_or_byte2 = max_char_or_byte2
	glyph_indices.min_byte1 = min_byte1
	glyph_indices.max_byte1 = max_byte1
	glyph_indices.default_char = default_char
	return glyph_indices
end
function pcf.tablereaders.glyph_names(self, f)
	local format = pcf.readformat(f)
	local glyph_count = string.unpack(format.endian .. 'i4', f:read(4))
	local glyph_name_offsets = {}
	for n=1,glyph_count do
		local offset = string.unpack(format.endian .. 'i4', f:read(4))
		glyph_name_offsets[n] = offset
	end
	local names = {}
	local strings_size = string.unpack(format.endian .. 'i4', f:read(4))
	local strings = f:read(strings_size)
	for n=1,glyph_count do
		local offset = glyph_name_offsets[n]
		local name = string.match(strings, "[^\0]*", offset+1)
		names[n] = name
	end
	return names
end
pcf.tablereaders.ink_metrics = pcf.tablereaders.metrics
pcf.tablereaders.bdf_encodings = pcf.tablereaders.encodings
pcf.tablereaders.bdf_accelerators = pcf.tablereaders.accelerators

return pcf
