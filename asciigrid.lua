local borders = {
	none = {},
	ascii = {      -- TBLR
		n   = " ", -- 0000
		r   = "-", -- 0001
		l   = "-", -- 0010
		lr  = "-", -- 0011
		b   = "'", -- 0100
		br  = "+", -- 0101
		bl  = "+", -- 0110
		blr = "+", -- 0111
		t   = ".", -- 1000
		tr  = "+", -- 1001
		tl  = "+", -- 1010
		tlr = "+", -- 1011
		tb  = "|", -- 1100
		tbr = "+", -- 1101
		tbl = "+", -- 1110
		x   = "+", -- 1111
	}
}

local function asciigrid(options)
	local function def(name, value)
		if options[name] == nil then
			options[name] = value
		end
		if type(value) == 'boolean' then
			options[name] = options[name] and true or false
		end
	end
	def('title', nil)
	def('rows', {})
	def('padleft', 1)
	def('padright', 1)
	def('padtop', 0)
	def('padbottom', 0)
	def('header_type', 'default')
	def('column_headers', nil)                       -- Specify the column headers (overrides and discards inner_heading if set)
	def('column_footers', nil)                       -- Specify the column footers (overrides and discards inner_footer if set)
	def('borders', 'ascii')                          -- Specify how to draw the borders
	def('inner_heading', false)                      -- The first row in rows is the heading
	def('inner_footing', false)                      -- The last row in rows is the footing
	def('inner_column_border', false)                -- Draw borders between column
	def('inner_row_border', false)                   -- Draw borders between rows
	def('inner_heading_row_border', true)            -- Draw borders between header and content
	def('inner_footing_row_border', true)            -- Draw borders between header and content
	def('outer_border', false)                       -- Draw borders around the table
	def('outer_border_left', options.outer_border)   -- Draw the left border?
	def('outer_border_right', options.outer_border)  -- Draw the right border?
	def('outer_border_top', options.outer_border)    -- Draw the top border?
	def('outer_border_bottom', options.outer_border) -- Draw the bottom border?
	def('column_justify', 'left')                    -- Justify the contents of a column
	if type(options.rows) ~= 'table' then
		return nil, 'rows must be a table'
	end
	if type(options.padleft) ~= 'number' then
		return nil, 'padleft must be a number'
	end
	if type(options.padright) ~= 'number' then
		return nil, 'padright must be a number'
	end
	if type(options.padtop) ~= 'number' then
		return nil, 'padtop must be a number'
	end
	if type(options.padbottom) ~= 'number' then
		return nil, 'padbottom must be a number'
	end
	if options.column_headers ~= nil and type(options.column_headers) ~= 'table' then
		return nil, 'column_heaader must be a table'
	end
	if options.column_footers ~= nil and type(options.column_footers) ~= 'table' then
		return nil, 'column_heaader must be a table'
	end
	if type(options.borders) == 'string' then
		options.borders = borders[options.borders]
	end
	if type(options.borders) ~= 'table' then
		return nil, 'invalid border option'
	end
	options.callbacks = type(options.callbacks) == 'table' and options.callbacks or {}
	if type(options.callbacks.column_to_string) ~= 'function' then
		options.callbacks.column_to_string = tostring
	end
	if type(options.callbacks.string_length) ~= 'function' then
		options.callbacks.string_length = string.len
	end
	if type(options.callbacks.column_width) ~= 'function' then
		options.callbacks.column_width = function(col)
			return options.callbacks.string_length(options.callbacks.column_to_string(col))
		end
	end
	local grid = {}
	grid.options       = options
	grid.rows          = options.rows
	grid.num_rows      = #options.rows -- The number of rows in this grid
	grid.num_cols      = 0             -- The number of columns in this grid
	grid.column_widths = {}            -- The width of each column, without padding or borders
	grid.column_pos    = {}            -- The x coordinate of the start of each column, including padding and borders
	grid.row_width     = 0             -- The total width of the grid, including padding and borders
	grid.lines         = {}            -- The lines that make up the final grid
	do -- calculate column widths and number of columns
		for nrow, row in ipairs(grid.rows) do
			for ncol, col in ipairs(row) do
				grid.column_widths[ncol] = math.max(grid.column_widths[ncol] or 0, options.callbacks.column_width(col))
			end
			grid.num_cols = math.max(grid.num_cols, #row)
		end
	end
	local inline_header = options.header_type == 'default'
	if inline_header then
		for ncol, width in ipairs(grid.column_widths) do
			grid.column_widths[ncol] = math.max(options.callbacks.string_length(options.column_headers[ncol]), width)
		end
	end
	local inline_footer = false
	do -- calculate column positions
		local cur = 1 + (options.outer_border_left and 1 or 0) + options.padleft
		for ncol, width in ipairs(grid.column_widths) do
			if options.column_justify == 'right' or type(options.column_justify) == 'table' and options.column_justify[ncol] == 'right' then
				grid.column_pos[ncol] = cur + width - 1
			elseif options.column_justify == 'center' or type(options.column_justify) == 'table' and options.column_justify[ncol] == 'center' then
				grid.column_pos[ncol] = cur + math.floor(width / 2)
			else
				grid.column_pos[ncol] = cur
			end
			cur = cur + width + options.padright + (options.inner_column_border and 1 or 0) + options.padleft
		end
	end
	do -- calculate row width
		if options.outer_border_left then
			grid.row_width = grid.row_width + 1
		end
		if options.outer_border_right then
			grid.row_width = grid.row_width + 1
		end
		if options.inner_column_border then
			grid.row_width = grid.row_width + grid.num_cols - 1
		end
		for ncol, width in ipairs(grid.column_widths) do
			grid.row_width = grid.row_width + options.padleft + width + options.padright
		end
	end
	do -- draw header
		if options.header_type == 'arrows' then
			if options.title then
				grid.lines[#grid.lines + 1] = options.title
			end
			for ncol, header in ipairs(options.column_headers) do
				local line = ''
				for x=1,grid.row_width do
					if x == grid.column_pos[ncol] then
						line = line .. '+'
					elseif x > grid.column_pos[ncol] then
						line = line .. '-'
					else
						local found = false
						for n=1, ncol do
							if grid.column_pos[n] == x then
								line = line .. '|'
								found = true
							end
						end
						if not found then
							line = line .. ' '
						end
					end
				end
				line = line .. ' ' .. header
				grid.lines[#grid.lines + 1] = line
			end
			do -- Draw the lines above the arrows
				local line = ''
				for x=1, grid.row_width do
					local found = false
					for n=1, grid.num_cols do
						if x == grid.column_pos[n] then
							line = line .. '|'
							found = true
						end
					end
					if not found then
						line = line .. ' '
					end
				end
				grid.lines[#grid.lines + 1] = line
			end
			do -- Draw the arrows
				local line = ''
				for x=1, grid.row_width do
					local found = false
					for n=1, grid.num_cols do
						if x == grid.column_pos[n] then
							line = line .. 'v'
							found = true
						end
					end
					if not found then
						line = line .. ' '
					end
				end
				grid.lines[#grid.lines + 1] = line
			end
		elseif options.header_type == 'default' then
			if options.outer_border_top then
				local line = ''
				line = line .. options.borders.br
				for ncol, width in ipairs(grid.column_widths) do
					if options.inner_column_border and ncol ~= 1 then
						line = line .. options.borders.blr
					end
					line = line .. string.rep(options.borders.lr, options.padleft + width + options.padright)
				end
				line = line .. options.borders.bl
				grid.lines[#grid.lines + 1] = line
			end
			local line = ''
			if options.outer_border_left then
				line = line .. options.borders.tb
			end
			for ncol, header in ipairs(options.column_headers) do
				if options.inner_column_border and ncol ~= 1 then
					line = line .. options.borders.tb
				end
				line = line .. string.rep(' ', options.padleft)
				if options.column_justify == 'right' or type(options.column_justify) == 'table' and options.column_justify[ncol] == 'right' then
					line = line .. string.rep(' ', grid.column_widths[ncol] - options.callbacks.string_length(header))
					line = line .. header
				elseif options.column_justify == 'center' or type(options.column_justify) == 'table' and options.column_justify[ncol] == 'center' then
					line = line .. string.rep(' ', math.floor((grid.column_widths[ncol] - options.callbacks.string_length(header)) / 2))
					line = line .. header
					line = line .. string.rep(' ', math.ceil((grid.column_widths[ncol] - options.callbacks.string_length(header)) / 2))
				else
					line = line .. header
					line = line .. string.rep(' ', grid.column_widths[ncol] - options.callbacks.string_length(header))
				end
				line = line .. string.rep(' ', options.padright)
			end
			if options.outer_border_right then
				line = line .. options.borders.tb
			end
			grid.lines[#grid.lines + 1] = line
			if options.inner_heading_row_border then
				local line = ''
				if options.outer_border then
					line = line .. options.borders.tbr
				end
				for ncol, width in ipairs(grid.column_widths) do
					if options.inner_column_border and ncol ~= 1 then
						line = line .. options.borders.x
					end
					line = line .. string.rep(options.borders.lr, options.padleft + width + options.padright)
				end
				if options.outer_border then
					line = line .. options.borders.tbl
				end
				grid.lines[#grid.lines + 1] = line
			end
		else
			return nil, 'invalid header type option'
		end
	end
	do -- draw grid
		if options.outer_border_top and not inline_header then
			local line = ''
			line = line .. options.borders.br
			for ncol, width in ipairs(grid.column_widths) do
				if options.inner_column_border and ncol ~= 1 then
					line = line .. options.borders.blr
				end
				line = line .. string.rep(options.borders.lr, options.padleft + width + options.padright)
			end
			line = line .. options.borders.bl
			grid.lines[#grid.lines + 1] = line
		end
		for nrow, row in ipairs(options.rows) do
			if options.inner_row_border and nrow ~= 1 then
				local line = ''
				if options.outer_border_left then
					line = line .. options.borders.tbr
				end
				for ncol, width in ipairs(grid.column_widths) do
					if options.inner_column_border and ncol ~= 1 then
						line = line .. options.borders.x
					end
					line = line .. string.rep(options.borders.lr, options.padleft + width + options.padright)
				end
				if options.outer_border_right then
					line = line .. options.borders.tbl
				end
				grid.lines[#grid.lines + 1] = line
			end
			for i=1,options.padtop do
				local line = ''
				if options.outer_border_left then
					line = line .. options.borders.tb
				end
				for ncol, width in ipairs(grid.column_widths) do
					if options.inner_column_border and ncol ~= 1 then
						line = line .. options.borders.tb
					end
					line = line .. string.rep(' ', options.padleft + width + options.padright)
				end
				if options.outer_border_right then
					line = line .. options.borders.tb
				end
				grid.lines[#grid.lines + 1] = line
			end
			do
				local line = ''
				if options.outer_border_left then
					line = line .. options.borders.tb
				end
				for ncol, col in ipairs(row) do
					if options.inner_column_border and ncol ~= 1 then
						line = line .. options.borders.tb
					end
					line = line .. string.rep(' ', options.padleft)
					if options.column_justify == 'right' or type(options.column_justify) == 'table' and options.column_justify[ncol] == 'right' then
						line = line .. string.rep(' ', grid.column_widths[ncol] - options.callbacks.column_width(col))
						line = line .. col
					elseif options.column_justify == 'center' or type(options.column_justify) == 'table' and options.column_justify[ncol] == 'center' then
						line = line .. string.rep(' ', math.floor((grid.column_widths[ncol] - options.callbacks.column_width(col)) / 2))
						line = line .. col
						line = line .. string.rep(' ', math.ceil((grid.column_widths[ncol] - options.callbacks.column_width(col)) / 2))
					else
						line = line .. col
						line = line .. string.rep(' ', grid.column_widths[ncol] - options.callbacks.column_width(col))
					end
					line = line .. string.rep(' ', options.padright)
				end
				if options.outer_border_right then
					line = line .. options.borders.tb
				end
				grid.lines[#grid.lines + 1] = line
			end
			for i=1,options.padbottom do
				local line = ''
				if options.outer_border_left then
					line = line .. options.borders.tb
				end
				for ncol, width in ipairs(grid.column_widths) do
					if options.inner_column_border and ncol ~= 1 then
						line = line .. options.borders.tb
					end
					line = line .. string.rep(' ', options.padleft + width + options.padright)
				end
				if options.outer_border_right then
					line = line .. options.borders.tb
				end
				grid.lines[#grid.lines + 1] = line
			end
		end
		if options.outer_border_bottom and not inline_footer then
			local line = ''
			line = line .. options.borders.tr
			for ncol, width in ipairs(grid.column_widths) do
				if options.inner_column_border and ncol ~= 1 then
					line = line .. options.borders.tlr
				end
				line = line .. string.rep(options.borders.lr, options.padleft + width + options.padright)
			end
			line = line .. options.borders.tl
			grid.lines[#grid.lines + 1] = line
		end
	end
	return grid
end

return asciigrid
