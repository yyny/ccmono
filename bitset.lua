#!/usr/bin/env lua
local mix = require "mix"
local bitset = {}

local function charoff(pos)
	return 1 + (pos - 1) // 8
end
local function charsize(size)
	return (size + 7) // 8
end
local function bitoff(pos)
	return (pos-1) & 7
end

local function mask(value, pos)
	return value | (1 << pos)
end
local function rmask(value, pos)
	return ~((~value) | (1 << pos))
end
local function setchar(s, pos, value)
	return table.concat({s:sub(1,pos-1), s:sub(pos+1)}, value)
end

local lastbits = {[0]='', '\x01', '\x03', '\x07', '\x0F', '\x10', '\x30', '\x70'}

local lookup = {}
for n=0,255 do
	local weight = 0
	for m=0,7 do
		if n & (1 << m) ~= 0 then
			weight = weight + 1
		end
	end
	lookup[n] = weight
end

local mt = {}
function bitset.new(sz)
	assert(math.type(sz) == 'integer' or type(sz) == 'string')
	local self = {}
	if type(sz) == 'string' then
		self.size = #sz*8
		self.data = sz
	else
		self.size = sz
		self.data = string.rep('\0', charsize(sz))
	end
	setmetatable(self, mt)
	return self
end
function bitset:isbitset()
	return getmetatable(self) == mt
end
function bitset:zero()
	self.data = string.rep('\0', charsize(self.size))
end
function bitset:fill(pos)
	self.data = string.rep('\xFF', charsize(self.size))
end
function bitset:len()
	return self.size
end
function bitset:get(pos)
	pos = math.tointeger(pos) or pos
	if math.type(pos) ~= 'integer' then
		return rawget(self, pos)
	end
	if pos < 0 or pos > self.size then
		return nil
	end
	local charpos = charoff(pos)
	local charvalue = string.byte(self.data:sub(charpos,charpos))
	return charvalue & (1 << bitoff(pos)) ~= 0
end
function bitset:set(pos, value)
	pos = math.tointeger(pos) or pos
	if math.type(pos) ~= 'integer' then
		rawset(self, pos, value)
		return true
	end
	assert(type(value) == 'boolean')
	if pos < 0 or pos > self.size then
		return false
	end
	local charpos = charoff(pos)
	local charvalue = string.byte(self.data:sub(charpos,charpos))
	charvalue = (value and mask or rmask)(charvalue, bitoff(pos))
	charvalue = string.char(charvalue)
	self.data = setchar(self.data, charoff(pos), charvalue)
	return true
end
function bitset:enable(pos)
	return self:set(pos, true)
end
function bitset:disable(pos)
	return self:set(pos, false)
end
function bitset:toggle(...) local args = {...}
	return self:set(pos, not self:get(pos))
end
function bitset:empty()
	return self.data == string.rep('\0', charsize(self.size))
end
function bitset:full()
	return self.data == string.rep('\xFF', self.size // 8) .. lastbits[self.size & 7]
end
function bitset:equal(other)
	return self.size == other.size and self.data == other.data
end
function bitset:clear(from, to)
	return false
end
function bitset:weight()
	local result = 0
	for n=1,#self.data do
		result = result + lookup[string.byte(self.data:sub(n,n))]
	end
	return result
end
function bitset:band(other)
	assert(self.size == other.size)
	local result = bitset(self.size)
	local t = {}
	for n=1,#self.data do
		t[#t+1] = string.char(string.byte(self.data:sub(n,n)) & string.byte(other.data:sub(n,n)))
	end
	result.data = table.concat(t)
	return result
end
function bitset:bor(other)
	assert(self.size == other.size)
	local result = bitset(self.size)
	local t = {}
	for n=1,#self.data do
		t[#t+1] = string.char(string.byte(self.data:sub(n,n)) | string.byte(other.data:sub(n,n)))
	end
	result.data = table.concat(t)
	return result
end
function bitset:bxor(other)
	assert(self.size == other.size)
	local result = bitset(self.size)
	local t = {}
	for n=1,#self.data do
		t[#t+1] = string.char(string.byte(self.data:sub(n,n)) ~ string.byte(other.data:sub(n,n)))
	end
	result.data = table.concat(t)
	return result
end
function bitset:bnot()
	local result = bitset(self.size)
	local t = {}
	for n=1,#self.data do
		t[#t+1] = string.char(0xFF - string.byte(self.data:sub(n,n)))
	end
	result.data = table.concat(t)
	return result
end
function bitset:tostring(charset)
	charset = charset or '01'
	local result = ''
	for n=1,#self do
		local idx = (self[n] and 2 or 1)
		result = result .. charset:sub(idx,idx)
	end
	return result
end
mt.__newindex = bitset.set
mt.__index = mix(bitset, bitset.get)
mt.__len = bitset.len
mt.__concat = bitset.concat
setmetatable(bitset, { __call = function (self, ...) return bitset.new(...) end })

return bitset
