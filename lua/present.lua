local M = {}

M.setup = function()
	-- Do nothing
end

---@class present.Float
---@field buf integer: Buffer id of floating window
---@field win integer: Window id of floating window

---Create a new floating window
---@param config vim.api.keyset.win_config
---@param enter boolean?: If true, set as current buffer
---@return present.Float
local function create_floating_window(config, enter)
	if enter == nil then
		enter = false
	end
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, enter or false, config)
	return { buf = buf, win = win }
end

---@class present.Slides
---@field slides present.Slide[]: The slides of the file

---@class present.Slide
---@field title string: The of the slide
---@field body string[]: The body of the slide
---@field blocks present.Block[]: A codeblock inside of a slide

---@class present.Block
---@field language string: the programming language of the codeblock
---@field body string: The body/text of the codeblock (Not including ``` guards)

--- Takes some lines and parses them
---@parem lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function(lines)
	---@type present.Slides
	local slides = { slides = {} }
	local current_slide = {
		title = "",
		body = {},
		blocks = {},
	}

	local seperator = "^#"

	for _, line in ipairs(lines) do
		if line:find(seperator) then
			if #current_slide.title > 0 then
				table.insert(slides.slides, current_slide)
			end

			current_slide = {
				title = line,
				body = {},
				blocks = {},
			}
		else
			table.insert(current_slide.body, line)
		end
	end
	table.insert(slides.slides, current_slide)

	for _, slide in ipairs(slides.slides) do
		local block = {
			language = nil,
			body = "",
		}
		local inside_block = false
		for _, line in ipairs(slide.body) do
			if vim.startswith(line, "```") then
				if not inside_block then
					inside_block = true
					block.language = string.sub(line, 4)
				else
					inside_block = false
					block.body = vim.trim(block.body)
					table.insert(slide.blocks, block)
				end
			elseif inside_block then
				block.body = block.body .. line .. "\n"
			end
		end
	end

	return slides
end

---Create default configurations for needed windows for presentation view
---@return table<string, vim.api.keyset.win_config>
local create_window_configurations = function()
	local width = vim.o.columns
	local height = vim.o.lines

	local header_height = 1 + 2 -- 1 + border
	local footer_height = 1 -- 1, no border
	local body_height = height - header_height - footer_height - 2 - 1 -- Height not used by header/footer + border

	return {
		background = {
			relative = "editor",
			width = width,
			height = height,
			style = "minimal",
			col = 0,
			row = 0,
			zindex = 1,
		},
		header = {
			relative = "editor",
			width = width,
			height = 1,
			border = "rounded",
			style = "minimal",
			col = 0,
			row = 0,
			zindex = 2,
		},
		body = {
			relative = "editor",
			width = width - 8,
			height = body_height,
			border = { " ", " ", " ", " ", " ", " ", " ", " " },
			style = "minimal",
			col = 8,
			row = 4,
			zindex = 2,
		},
		footer = {
			relative = "editor",
			width = width,
			height = footer_height,
			-- border = "rounded", TODO: Just a border along the top?
			style = "minimal",
			col = 0,
			row = height - 1,
			zindex = 2,
		},
	}
end

---@class present.State
---@field title string: Name of the file being presented
---@field parsed present.Slides: Slides to present
---@field floats table<string, present.Float>: Table of all floating windows for present view
---@field current_slide integer: Index of current slide to present
local state = {
	title = "",
	parsed = { slides = {} },
	floats = {},
	current_slide = 1,
}

---Run callback for each float
---@param callback function<string, table<string, present.Float>>
local foreach_float = function(callback)
	for name, float in pairs(state.floats) do
		callback(name, float)
	end
end

---Set keymap for presentation mode only
---@param mode string
---@param key string
---@param callback function
local present_keymap = function(mode, key, callback)
	vim.keymap.set(mode, key, callback, {
		buffer = state.floats.body.buf,
	})
end

---Set lines of given buffer
---@param buf integer: ID of the buffer to set lines for
---@param lines string[]: Content to set buffer to
local buf_set_lines = function(buf, lines)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

M.start_presentation = function(opts)
	opts = opts or {}
	opts.bufnr = opts.bufnr or 0

	local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
	state.parsed = parse_slides(lines)
	state.current_slide = 1
	state.title = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.bufnr), ":t")
	-- state.title = string.sub(state.title, 0, -4)

	local windows = create_window_configurations()
	state.floats.background = create_floating_window(windows.background)
	state.floats.header = create_floating_window(windows.header)
	state.floats.body = create_floating_window(windows.body, true)
	state.floats.footer = create_floating_window(windows.footer)

	foreach_float(function(_, float)
		vim.bo[float.buf].filetype = "markdown"
	end)

	local set_slide_content = function(idx)
		local width = vim.o.columns
		local slide = state.parsed.slides[idx]

		local padding = string.rep(" ", (width - #slide.title) / 2)
		local title = padding .. slide.title

		buf_set_lines(state.floats.header.buf, { title })
		buf_set_lines(state.floats.body.buf, slide.body)

		local footer = string.format("  %d / %d | %s", state.current_slide, #state.parsed.slides, state.title)
		buf_set_lines(state.floats.footer.buf, { footer })
	end

	present_keymap("n", "n", function()
		state.current_slide = math.min(state.current_slide + 1, #state.parsed.slides)
		set_slide_content(state.current_slide)
	end)

	present_keymap("n", "p", function()
		state.current_slide = math.max(1, state.current_slide - 1)
		set_slide_content(state.current_slide)
	end)

	present_keymap("n", "q", function()
		vim.api.nvim_win_close(state.floats.body.win, true)
	end)

	present_keymap("n", "X", function()
		local slide = state.parsed.slides[state.current_slide]
		-- TODO: Make a way for people to execute this for other languages
		local block = slide.blocks[1]
		if not block then
			print("No blocks on this page")
			return
		end

		-- Override the default print function, to capture all of the output
		local original_print = print

		-- table to capture print messages
		local output = { "", "# Code", "", "```" .. block.language }
		vim.list_extend(output, vim.split(block.body, "\n"))
		table.insert(output, "```")

		-- Redefine the print function
		print = function(...)
			local args = { ... }
			local message = table.concat(vim.tbl_map(tostring, args), "\t")
			table.insert(output, message)
		end

		-- Call the provided function
		local chunk = loadstring(block.body)
		pcall(function()
			table.insert(output, "")
			table.insert(output, "# Output")
			table.insert(output, "")
			if not chunk then
				table.insert(output, " <<<BROKEN CODE>>>")
			else
				chunk()
			end
		end)

		print = original_print

		local buf = vim.api.nvim_create_buf(false, true)
		local temp_width = math.floor(vim.o.columns * 0.8)
		local temp_height = math.floor(vim.o.lines * 0.8)
		vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			style = "minimal",
			width = temp_width,
			height = temp_height,
			row = math.floor((vim.o.lines - temp_height) / 2),
			col = math.floor((vim.o.columns - temp_width) / 2),
		})

		vim.bo[buf].filetype = block.language
		buf_set_lines(buf, output)
	end)

	local restore = {
		cmdheight = {
			original = vim.o.cmdheight,
			present = 0,
		},
	}

	-- Set the options we want during presentation
	for option, config in pairs(restore) do
		vim.opt[option] = config.present
	end

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = state.floats.body.buf,
		callback = function()
			-- Reset the values when we are done with the presentation
			for option, config in pairs(restore) do
				vim.opt[option] = config.original
			end

			foreach_float(function(_, float)
				pcall(vim.api.nvim_win_close, float.win, true)
			end)
		end,
	})

	vim.api.nvim_create_autocmd("VimResized", {
		group = vim.api.nvim_create_augroup("present-resized", {}),
		callback = function()
			if not vim.api.nvim_win_is_valid(state.floats.body.win) or state.floats.body.win == nil then
				return
			end

			local updated = create_window_configurations()
			foreach_float(function(name, _)
				vim.api.nvim_win_set_config(state.floats[name].win, updated[name])
			end)
			set_slide_content(state.current_slide)
		end,
	})

	set_slide_content(state.current_slide)
end

-- M.start_presentation({ bufnr = 104 })

M._parse_slides = parse_slides

return M
