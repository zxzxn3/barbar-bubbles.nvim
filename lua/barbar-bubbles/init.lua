-- Bubbles companion style for Barbar: lualine colors and curved tab edges.
local M = {}
local initialized = false
local joins = {}

-- Reuse lualine palettes: main for current, secondary for visible, inactive for hidden.
local function rounded_colors()
  joins = {}
  local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
  local fill = vim.api.nvim_get_hl(0, { name = 'BufferTabpageFill', link = false })
  -- Match lualine's default diff color sources and fallback colors.
  local git_colors = {}
  for part, spec in pairs({
    ADDED = { 'Add', 'Added', '#90ee90' },
    CHANGED = { 'Change', 'Changed', '#f0e130' },
    DELETED = { 'Delete', 'Removed', '#ff0038' },
  }) do
    git_colors[part] = spec[3]
    for _, group in ipairs({ 'LuaLineDiff' .. spec[1], 'GitSigns' .. spec[1],
      'GitGutter' .. spec[1], 'Diff' .. spec[2], 'Diff' .. spec[1] }) do
      local fg = vim.api.nvim_get_hl(0, { name = group, link = false }).fg
      if fg then git_colors[part] = fg; break end
    end
  end
  local parts = { 'ADDED', 'Btn', 'CHANGED', 'DELETED', 'ERROR', 'HINT', 'Index',
    'INFO', 'Mod', 'ModBtn', 'Number', 'Pin', 'PinBtn', 'Target', 'WARN' }
  for _, state in ipairs({ 'Current', 'Visible', 'Inactive', 'Alternate' }) do
    local palette = state == 'Current' and 'lualine_a_normal'
      or state == 'Visible' and 'lualine_b_normal' or 'lualine_a_inactive'
    local color = vim.api.nvim_get_hl(0, { name = palette, link = false })
    local prefix = 'Buffer' .. state
    vim.api.nvim_set_hl(0, prefix, { fg = color.fg, bg = color.bg, bold = true })
    vim.api.nvim_set_hl(0, prefix .. 'Icon', { link = prefix })
    -- Preserve Git/diagnostic foregrounds while matching the item background.
    for _, part in ipairs(parts) do
      local name = prefix .. part
      local attributes = vim.api.nvim_get_hl(0, { name = name, link = false })
      attributes.bg = color.bg
      if git_colors[part] then attributes.fg = git_colors[part] end
      vim.api.nvim_set_hl(0, name, attributes)
    end
    local ends = { fg = color.bg or normal.bg, bg = fill.bg or normal.bg }
    -- Reverse visible tabs' left edges to cut into their colored backgrounds.
    vim.api.nvim_set_hl(0, 'Buffer' .. state .. 'Sign', (state == 'Current' or state == 'Visible')
      and { fg = ends.bg, bg = ends.fg } or ends)
    vim.api.nvim_set_hl(0, 'Buffer' .. state .. 'SignRight', ends)
    -- Prepare adjacent-tab transitions once per theme, not on every redraw.
    for _, right in ipairs({ 'Current', 'Visible' }) do
      local palette = right == 'Current' and 'lualine_a_normal' or 'lualine_b_normal'
      local target = vim.api.nvim_get_hl(0, { name = palette, link = false })
      if color.bg ~= target.bg then
        local group = 'BarbarBubbles' .. state .. right
        vim.api.nvim_set_hl(0, group, { fg = color.bg, bg = target.bg })
        joins[state .. right] = group
      end
    end
  end
end

-- Join different-colored tabs; keep same-colored notches and flatten the first tab's left edge.
local function rounded_edges(line, flat_first)
  if not line then return line end
  line = line:gsub('%%#Buffer(%a+)SignRight#([%%@%w_#]*)%%#Buffer(%a+)Sign#',
    function(left, click, right)
      local group = joins[left .. right]
      if group then return '%#Buffer' .. left .. '# ' .. click .. '%#' .. group .. '#' end
      -- Returning nil leaves the original separators intact.
    end)
  local first = line:find('%%#Buffer%a+Sign#')
  if flat_first and first then
    line = line:sub(1, first - 1) .. line:sub(first):gsub(
      '^%%#Buffer(%a+)Sign#(...)', function(state, edge)
        if edge == '' or edge == '' then return '%#Buffer' .. state .. '# ' end
      end, 1)
  end
  return line
end

-- Options consumed by barbar.setup; this module does not configure the plugin itself.
M.barbar_options = {
  icons = {
    filetype = { custom_colors = true },
    separator = { left = '', right = '' },
    separator_at_end = false,
    current = { separator = { left = '', right = '' } },
    visible = { separator = { left = '', right = '' } },
    inactive = { separator = { left = '', right = '' } },
  },
}

-- Apply colors; install theme refresh and tab-edge rendering adapters once.
function M.setup(options)
  local flat_first = not options or options.flat_first ~= false
  rounded_colors()
  if initialized then return end
  initialized = true
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('barbar_rounded', { clear = true }),
    callback = function() vim.schedule(rounded_colors) end,
  })
  -- Barbar has no adjacent-tab separator callback; adapt only the final tabline.
  local render = require('barbar.ui.render')
  local set_tabline = render.set_tabline
  render.set_tabline = function(line)
    return set_tabline(rounded_edges(line, flat_first))
  end
end

return M
