#!/usr/bin/env lua

-- Library for reading BMP files
-- Incomplete; cannot read all compression formats
local headertypes = {}
headertypes["BITMAPCOREHEADER"]   = 12
headertypes["BITMAPINFOHEADER"]   = 40
headertypes["BITMAPV2INFOHEADER"] = 52
headertypes["BITMAPV3INFOHEADER"] = 56
headertypes["BITMAPV4HEADER"]     = 108
headertypes["BITMAPV5HEADER"]     = 124

headertypes["OS21XBITMAPHEADER"]  = 12
headertypes["OS22XBITMAPHEADER"]  = 16
headertypes["OS22XBITMAPHEADER"]  = 64

headertypes[12]  = "BITMAPCOREHEADER (or OS21XBITMAPHEADER)"
headertypes[40]  = "BITMAPINFOHEADER"
headertypes[52]  = "BITMAPV2INFOHEADER"
headertypes[56]  = "BITMAPV3INFOHEADER"
headertypes[108] = "BITMAPV4HEADER"
headertypes[124] = "BITMAPV5HEADER"

headertypes[16]  = "OS22XBITMAPHEADER"
headertypes[64]  = "OS22XBITMAPHEADER"

local compressiontypes = {}
compressiontypes[0 ] = "BI_RGB"            -- none                          | Most common
compressiontypes[1 ] = "BI_RLE8"           -- RLE 8-bit/pixel               | Can be used only with 8-bit/pixel bitmaps
compressiontypes[2 ] = "BI_RLE4"           -- RLE 4-bit/pixel               | Can be used only with 4-bit/pixel bitmaps
compressiontypes[3 ] = "BI_BITFIELDS"      -- OS22XBITMAPHEADER: Huffman 1D | BITMAPV2INFOHEADER: RGB bit field masks, BITMAPV3INFOHEADER+: RGBA
compressiontypes[4 ] = "BI_JPEG"           -- OS22XBITMAPHEADER: Huffman 1D | OS22XBITMAPHEADER: RLE-24 BITMAPV4INFOHEADER+: JPEG image for printing[12]
compressiontypes[5 ] = "BI_PNG"            --                               | BITMAPV4INFOHEADER+: PNG image for printing[12]
compressiontypes[6 ] = "BI_ALPHABITFIELDS" -- RGBA bit field masks          | only Windows CE 5.0 with .NET 4.0 or later
compressiontypes[11] = "BI_CMYK"           -- none                          | only Windows Metafile CMYK[3]
compressiontypes[12] = "BI_CMYKRLE8"       -- RLE-8                         | only Windows Metafile CMYK
compressiontypes[13] = "BI_CMYKRLE4"       -- RLE-4                         | only Windows Metafile CMYK

local bmp = {}
function bmp.read(f)
	local header = bmp.read_file_header(f)
	local result = bmp.read_header(f, header.imagedata_offset)
	result.header = header
	return result
end
function bmp.read_file_header(f)
	local magic = f:read(2)
	if magic ~= 'BM' and magic ~= 'BA' and magic ~= 'CI' and magic ~= 'CP' and magic ~= 'IC' and magic ~= 'PT' then
		return nil, 'invalid header start'
	end
	string.unpack('<I4', f:read(4))
	local reserved = f:read(4)
	local imageoff = string.unpack('<I4', f:read(4))
	return { header=magic, reserved=reserved, imagedata_offset=imageoff }
end
function bmp.read_header(f, imagedata_offset)
	local result = {}
	result.size = string.unpack('<I4', f:read(4))
	result.width = string.unpack('<I4', f:read(4))
	result.height = string.unpack('<I4', f:read(4))
	result.colorplanes = string.unpack('<I2', f:read(2))
	result.colordepth = string.unpack('<I2', f:read(2))
	if result.size >= 40 then
		result.compression = string.unpack('<I4', f:read(4))
		result.filesize = string.unpack('<I4', f:read(4))
		result.hresolution = string.unpack('<i4', f:read(4))
		result.vresolution = string.unpack('<i4', f:read(4))
		result.ncolors = string.unpack('<I4', f:read(4))
		result.importantcolors = string.unpack('<I4', f:read(4))
	end
	if result.size >= 52 then
		result.redmask = string.unpack('<I4', f:read(4))
		result.greenmask = string.unpack('<I4', f:read(4))
		result.bluemask = string.unpack('<I4', f:read(4))
	end
	if result.size >= 56 then
		result.alphamask = string.unpack('<I4', f:read(4))
	end
	if result.size >= 108 then
		result.colorspace = {}
		result.colorspace.type = string.unpack('<I4', f:read(4))
		result.colorspace.endpoints = f:read(36)
		result.redgamma   = string.unpack('<I4', f:read(4))
		result.greengamma = string.unpack('<I4', f:read(4))
		result.bluegamma  = string.unpack('<I4', f:read(4))
	end
	if result.size >= 124 then
		result.intent      = string.unpack('<I4', f:read(4))
		result.profiledata = string.unpack('<I4', f:read(4))
		result.profilesize = string.unpack('<I4', f:read(4))
		result.reserved    = string.unpack('<I4', f:read(4))
	end

	result.colors = {}
	if result.ncolors and result.ncolors > 0 then
		for n=0,result.ncolors do
			result.colors[n] = string.unpack('<I4', f:read(4))
		end
	end
	local gapsize = imagedata_offset - f:seek()
	if gapsize > 0 then f:read(gapsize) end
	result.data = {}
	for y=1,result.height do
		result.data[y] = {}
	end
	if result.compression == 0 then
		for y=result.height-1,1,-1 do
			for x=1,result.width do
				local b,g,r = string.unpack('BBB', f:read(3))
				result.data[y][x] = { r, g, b }
			end
			f:read(3 - ((f:seek()-1) % 4))
		end
	elseif result.compression == 1 then
		local x = 1
		local y = result.height-1
		while true do
			local rep = string.unpack('B', f:read(1))
			if rep == 0 then
				local command = string.unpack('B', f:read(1))
				if command == 0 then
					-- next line
					x = 1
					y = y - 1
				elseif command == 1 then
					-- end of bitmap
					break
				elseif command == 2 then
					local dx = string.unpack('B', f:read(1))
					local dy = string.unpack('B', f:read(1))
					-- delta
					error('not implemented')
				else
					for n=1,command do
						result.data[y][x] = string.unpack('B', f:read(1))
						x = x + 1
					end
				end
			else
				local color = string.unpack('B', f:read(1))
				for n=1,rep do
					result.data[y][x] = color
					x = x + 1
				end
			end
		end
	else
		error 'compression mode not yet supported'
	end

	return result
end
return bmp
