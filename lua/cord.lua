local cord = {}

local ffi = require('ffi')
local discord

local function init()
  local function get_os()
    return vim.loop.os_uname().sysname
  end

  local function file_exists(filename)
    local stat = vim.loop.fs_stat(filename)
    return stat and stat.type == 'file'
  end

  local function move_file(src, dest)
    local result, err = os.rename(src, dest)
    if not result then
      vim.api.nvim_err_writeln('[cord.nvim] Error moving file: ' .. err)
    end
  end

  local extension
  local os_name = get_os()
  if os_name:find('Windows', 1, true) == 1 then
    extension = '.dll'
  elseif os_name == 'Linux' then
    extension = '.so'
  elseif os_name == 'Darwin' then
    extension = '.dylib'
  else
    vim.api.nvim_err_writeln('[cord.nvim] Unable to identify OS type')
  end

  local path = debug.getinfo(2, 'S').source:sub(2, -14)
  local old_path = path .. '/build/bin/native/releaseShared/cord' .. extension
  local new_path = path .. '/cord' .. extension
  if file_exists(old_path) then
    os.remove(new_path)
    move_file(old_path, new_path)
  end

  ffi.cdef[[
    const char* init(const char*, const char*, const char*, const char*, const char*, const char*, const char*, const char*, const char*);
    void update_presence(const char*, const char*, bool);
    void clear_presence();
    void disconnect();
    void set_cwd(const char*);
    void set_time();
    void set_repository_url(const char*);
  ]]

  discord = ffi.load(new_path)
end

local function fetch_repository()
  local command = string.format('git -C %s config --get remote.origin.url', vim.fn.expand('%:p:h'))
  local handle = io.popen(command)
  if handle == nil then
    vim.notify('[cord.nvim] Could not fetch Git repository URL', vim.log.levels.WARN)
    return
  end
  local git_url = handle:read('*a')
  handle:close()

  return git_url:gsub('^%s+', ''):gsub('%s+$', '')
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

local config = {
  usercmds = true,
  timer = {
    enable = true,
    interval = 1500,
    reset_on_idle = false,
    reset_on_change = false,
  },
  editor = {
    image = nil,
    client = 'neovim',
    description = 'The Superior Text Editor',
  },
  display = {
    show_time = true,
    show_repository = true,
  },
  idle = {
    enable = true,
    text = 'Idle',
  },
  text = {
    viewing = 'Viewing $s',
    editing = 'Editing $s',
    file_browser = 'Browsing files in $s',
    plugin_manager = 'Managing plugins in $s',
    workspace = 'In $s',
  }
}

local enabled = false
local is_focused = true
local last_presence
local function start_timer(timer, config)
  if vim.g.cord_started == nil then
    vim.g.cord_started = true
    if config.text.workspace ~= '' and string.find(config.text.workspace, '$s') then
      discord.set_cwd(find_workspace())
      if config.display.show_repository then
        local repo = fetch_repository()
        if repo and repo ~= '' then
          discord.set_repository_url(repo)
        end
      end
      vim.api.nvim_create_autocmd('DirChanged', {
        callback = function()
          discord.set_cwd(find_workspace())
          if config.display.show_repository then
            local repo = fetch_repository()
            if repo and repo ~= '' then
              discord.set_repository_url(repo)
            end
          end
        end
      })
    end
    if config.display.show_time then
      discord.set_time()
    end
    if config.idle.enable then
      vim.api.nvim_create_autocmd('FocusGained', {
        callback = function()
          if config.display.show_time and config.timer.reset_on_idle then
            discord.set_time()
          end
          is_focused = true
        end
      })
      
      vim.api.nvim_create_autocmd('FocusLost', {
        callback = function()
          is_focused = false
          last_presence = nil
          discord.update_presence('', 'Cord.idle', false)
        end
      })
    end
  end
  timer:stop()
  timer:start(0, math.min(config.timer.interval, 500), vim.schedule_wrap(function()
    if not is_focused then
      return
    end

    local current_presence = { name = vim.fn.expand('%:t'), type = vim.bo.filetype, readonly = vim.bo.readonly }
    if last_presence and current_presence.name == last_presence.name and current_presence.type == last_presence.type and current_presence.readonly == last_presence.readonly then
      return
    end

    if config.display.show_time and config.timer.reset_on_change then
      discord.set_time()
    end

    discord.update_presence(current_presence.name, current_presence.type, current_presence.readonly)
    enabled = true
    last_presence = current_presence
  end))
end

function cord.setup(userConfig)
  if vim.g.cord_initialized == nil then
    local timer = vim.loop.new_timer()
    local config = vim.tbl_deep_extend('force', config, userConfig)
    local work = vim.loop.new_async(vim.schedule_wrap(function()
      init()
      local err = discord.init(
        config.editor.client,
        config.editor.image,
        config.editor.description,
        config.idle.text,
        config.text.viewing,
        config.text.editing,
        config.text.file_browser,
        config.text.plugin_manager,
        config.text.workspace
      )
      if err ~= nil then
        vim.api.nvim_err_writeln('[cord.nvim] Caught unexpected error: ' .. ffi.string(err))
      end

      if config.timer.enable then
        start_timer(timer, config)
      end

      vim.api.nvim_create_autocmd('ExitPre', {
        callback = function()
          discord.disconnect()
        end
      })

      vim.api.nvim_create_user_command('DiscordInit', function()
        local err = discord.init(
          config.editor.client,
          config.editor.image,
          config.editor.description,
          config.idle.text,
          config.text.viewing,
          config.text.editing,
          config.text.file_browser,
          config.text.plugin_manager,
          config.text.workspace
        )
        if err ~= nil then
          vim.api.nvim_err_writeln('[cord.nvim] Caught unexpected error: ' .. ffi.string(err))
        end
        start_timer(timer, config)
      end, {})

      if config.usercmds then
        vim.api.nvim_create_user_command('DiscordShow', function()
          start_timer(timer, config)
        end, {})
    
        vim.api.nvim_create_user_command('DiscordRestart', function()
          timer:stop()
          discord.disconnect()
          enabled = false
          local err = discord.init(
            config.editor.client,
            config.editor.image,
            config.editor.description,
            config.idle.text,
            config.text.viewing,
            config.text.editing,
            config.text.file_browser,
            config.text.plugin_manager,
            config.text.workspace
          )
          if err ~= nil then
            vim.api.nvim_err_writeln('[cord.nvim] Caught unexpected error: ' .. ffi.string(err))
          end
          start_timer(timer, config)
        end, {})
    
        vim.api.nvim_create_user_command('DiscordHide', function()
          timer:stop()
          enabled = false
          discord.clear_presence()
        end, {})
    
        vim.api.nvim_create_user_command('DiscordShutdown', function()
          timer:stop()
          enabled = false
          discord.disconnect()
        end, {})
  
        vim.api.nvim_create_user_command('DiscordToggle', function()
          if enabled then
            timer:stop()
            enabled = false
            discord.clear_presence()
          else
            start_timer(timer, config)
          end
        end, {})
      end
    end))
    work:send()
    vim.g.cord_initialized = true
  end
end

return cord
