local M = {}

M.setup = function ()
  -- nothing
end

local function create_floating_window(opts)
    opts = opts or {}
    local width = opts.width or math.floor(vim.o.columns * 0.8)
    local height = opts.height or math.floor(vim.o.lines * 0.8)

    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)

    local win_config = {
      relative = "editor",
      width = width,
      height = height,
      col = col,
      row = row,
      style = "minimal",
      border = "rounded"
    }

    local win = vim.api.nvim_open_win(buf, true, win_config)

    return { buf = buf, win = win }
end

---@class present.Slides
---@field slides string[][]: The slides of the file

--- Takes some lines and parses them
---@parem lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function (lines)
  local slides = { slides = {} }
  local current_slide = {}

  local seperator = "^#"

  for _, line in ipairs(lines) do
    if line:find(seperator) then
      if #current_slide > 0 then
      	table.insert(slides.slides, current_slide)
      end

      current_slide = {}
    end

    table.insert(current_slide, line)
  end
  table.insert(slides.slides, current_slide)

  return slides
end

-- vim.print(parse_slides {
--   "# Hello",
--   "This is the first slide",
--   "# World",
--   "This is the second slide",
-- })
M.start_presentation = function (opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0

  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  local parsed = parse_slides(lines)
  local float = create_floating_window({ buf = opts.bufnr })

  local current_slide = 1
  vim.keymap.set("n", "n", function ()
    current_slide = math.min(current_slide + 1, #parsed.slides)
    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
  end, { buffer = float.buf })

  vim.keymap.set("n", "p", function ()
    current_slide = math.max(1, current_slide - 1)
    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
  end, { buffer = float.buf })

  vim.keymap.set("n", "q", function ()
    vim.api.nvim_win_close(float.win, true)
  end, { buffer = float.buf })

  vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[1])
end

M.start_presentation { bufnr = 6 }

return M

