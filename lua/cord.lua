local cord = {}

local discord

local function init()
  local function is_windows()
    return package.config:sub(1, 1) == '\\'
  end

  local function file_exists(filename)
    local stat = vim.loop.fs_stat(filename)
    return stat and stat.type == 'file'
  end

  local ffi = require('ffi')
  local path = debug.getinfo(2, 'S').source:sub(2, -14)
  local dll_path
  if is_windows() then
    dll_path = path .. '/build/bin/native/releaseShared/cord.dll'
  else
    dll_path = path .. '/build/bin/native/releaseShared/cord.so'
    if not file_exists(dll_path) then
      dll_path = path .. '/build/bin/native/releaseShared/cord.dylib'
    end
  end

  ffi.cdef[[
    const char* init(const char*, const char*, const char*, const char*, const char*, const char*, const char*, const char*);
    const char* update_presence(const char*, const char*, bool);
    void disconnect();
    void set_cwd(const char*);
  ]]

  discord = ffi.load(dll_path)
end

local function find_workspace()
  local curr_dir = vim.fn.expand('%:p:h')
  local root_markers = {'.git', '.hg', '.svn'}
  local marker_path

  while curr_dir ~= '' do
    for _, marker in ipairs(root_markers) do
      marker_path = curr_dir .. '/' .. marker
      if vim.fn.isdirectory(marker_path) == 1 then
        return vim.fn.fnamemodify(curr_dir, ':t')
      end
    end

    curr_dir = vim.fn.fnamemodify(curr_dir, ':h')
    if curr_dir == vim.fn.fnamemodify(curr_dir, ':h') then break end
  end

  return vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
end

local function with_defaults(options)
  options = options or {}
  return {
    enable_timer = options.enable_timer or true,
    timer_interval = options.timer_interval or 1500,
    show_repository = options.show_repository or false,             -- todo
    show_time = options.show_time or true,                          -- todo
    reset_time_on_change = options.reset_time_on_change or true,    -- todo
    reset_time_on_idle = options.reset_time_on_idle or true,        -- todo
    editor = options.editor or 'neovim',                            -- todo
    description = options.description or 'The Superior Text Editor',
    idle = options.idle or 'Idle',
    viewing = options.viewing or 'Viewing $s',
    editing = options.editing or 'Editing $s',
    file_browser = options.file_browser or 'Browsing files in $s',
    plugin_manager = options.plugin_manager or 'Managing packages in $s',
    workspace = options.workspace or 'In $s',
  }
end

function cord.setup(userConfig)
  if vim.g.cord_initialized == nil then
    init()
    local config = with_defaults(userConfig)
    local is_focused = true
    local work = vim.loop.new_async(vim.schedule_wrap(function()
      local err = discord.init(
        config.editor,
        config.description,
        config.idle,
        config.viewing,
        config.editing,
        config.file_browser,
        config.plugin_manager,
        config.workspace
      )
      if err ~= nil then
        vim.api.nvim_err_writeln('[cord.nvim] Caught unexpected error: ' .. err)
      end

      if config.workspace ~= '' then
        discord.set_cwd(find_workspace())
        vim.api.nvim_create_autocmd('DirChanged', {
          callback = function()
            discord.set_cwd(find_workspace())
          end
        })
      end

      if config.enable_timer then
        local last = { name = '', type = '', readonly = false }

        local timer = vim.loop.new_timer()
        timer:start(0, math.min(config.timer_interval, 500), vim.schedule_wrap(function()
          if not is_focused then
            return
          end

          local current = { name = vim.fn.expand('%:t'), type = vim.bo.filetype, readonly = vim.bo.readonly }
          if current.name == last.name and current.type == last.type and current.readonly == last.readonly then
            return
          end
          local err = discord.update_presence(current.name, current.type, current.readonly)
          if err ~= nil then
            vim.api.nvim_err_writeln('[cord.nvim] Caught unexpected error: ' .. err)
          end
          last = current
        end))
      end
    end))
    work:send()

    vim.api.nvim_create_autocmd('ExitPre', {
      callback = function()
        discord.disconnect()
      end
    })

    if config.idle ~= '' then
      vim.api.nvim_create_autocmd('FocusGained', {
        callback = function()
          is_focused = true
        end
      })
      
      vim.api.nvim_create_autocmd('FocusLost', {
        callback = function()
          is_focused = false
          discord.update_presence('', 'cord.idle', false)
        end
      })
    end
    vim.g.cord_initialized = true
  end
end

return cord