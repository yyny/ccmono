#!/usr/bin/env lua

local esc_ascii_ctrl = false -- Should we escape all ascii control characters?
local esc_uni_ctrl = true -- Should we escape all unicode control characters?
local chars_per_row = 8

local cols = chars_per_row
local rows = (256//chars_per_row)

-- The following characters will not be printed normally; they are control
--  characters without representation, glyphs which aren't one characters wide,
--  or other special characters that we would like to escape.
local esc = {
	[0]   = '\\0',
	[5]   = '[ENQ]',
	[7]   = '\\a',
	[8]   = '\\b',
	[9]   = '\\t',
	[10]  = '\\n',
	[11]  = '\\v',
	[12]  = '\\f',
	[13]  = '\\r',
	[14]  = '[SO]',
	[15]  = '[SI]',
	[39]  = '\\\'',
	[127] = '[DEL]',
}
if esc_ascii_ctrl then
	for n=0,31 do
		esc[n] = esc[n] or string.format('\\x%02x', n)
	end
end
if esc_uni_ctrl then
	for n=0x80,0xA0 do
		esc[n] = esc[n] or string.format('\\u{%04X}', n)
	end
end
local res = {}
for n=0,255 do
	res[#res+1] = table.concat { '| ', string.format('%-4d', n), ": '", esc[n] and esc[n] or utf8.char(n), "' " }
end
local ws = {}
for y=1,cols do
	local max = 0
	for x=1,rows do
		local s = res[(y-1)*rows+x]
		max = math.max(max, utf8.len(s))
	end
	ws[y] = max
end
for y=1,cols do
	io.write('+', string.rep('-', ws[y]-1))
end
io.write('+\n')
for x=1,rows do
	for y=1,cols do
		local s = res[(y-1)*rows+x]
		io.write(s, string.rep(' ', ws[y] - utf8.len(s)))
		if y == cols then
			io.write('|')
		end
	end
	io.write('\n')
end
for y=1,cols do
	io.write('+', string.rep('-', ws[y]-1))
end
io.write('+\n')
