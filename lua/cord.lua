local cord = {}

local ffi = require('ffi')
local utils = require('utils')
local discord

cord.config = {
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
    tooltip = 'The Superior Text Editor',
  },
  display = {
    show_time = true,
    show_repository = true,
    show_cursor_position = false,
  },
  lsp = {
    show_problem_count = false,
    severity = 1,
    scope = 'workspace',
  },
  idle = {
    show_idle = true,
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
local problem_count = -1
local last_presence
local function start_timer(timer, config)
  if vim.g.cord_started == nil then
    vim.g.cord_started = true
    if config.text.workspace ~= '' and string.find(config.text.workspace, '$s') then
      discord.set_cwd(utils.find_workspace())
      if config.display.show_repository then
        local repo = utils.fetch_repository()
        if repo and repo ~= '' then
          discord.set_repository_url(repo)
        end
      end
      vim.api.nvim_create_autocmd('DirChanged', {
        callback = function()
          discord.set_cwd(utils.find_workspace())
          if config.display.show_repository then
            local repo = utils.fetch_repository()
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
    if config.idle.show_idle then
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
          discord.update_presence('', 'Cord.idle', false, nil, 0)
        end
      })
    end
    if config.lsp.show_problem_count then
      config.lsp.severity = tonumber(config.lsp.severity)
      if config.lsp.severity == nil or config.lsp.severity < 1 or config.lsp.severity > 4 then
        vim.api.nvim_err_writeln('[cord.nvim] config.lsp.severity value must be a number between 1 and 4')
        return
      end
    end
  end
  timer:stop()
  timer:start(0, math.max(config.timer.interval, 500), vim.schedule_wrap(function()
    if not is_focused then
      return
    end

    local cursor_position
    if config.display.show_cursor_position then
      local cursor = vim.api.nvim_win_get_cursor(0)
      cursor_position = cursor[1] .. ':' .. cursor[2]
    end
    
    if config.lsp.show_problem_count then
      local bufnr
      if config.lsp.scope == 'buffer' then
        bufnr = vim.api.nvim_get_current_buf()
      elseif config.lsp.scope ~= 'workspace' then
        vim.api.nvim_err_writeln('[cord.nvim] config.lsp.scope value must be either workspace or buffer')
      end
      problem_count = #vim.diagnostic.get(bufnr, { severity = { min = config.lsp.severity } })
    end
    
    local current_presence = { name = vim.fn.expand('%:t'), type = vim.bo.filetype, readonly = vim.bo.readonly, cursor = cursor_position, problems = problem_count }
    if last_presence and current_presence.cursor == last_presence.cursor and current_presence.problems == last_presence.problems and current_presence.name == last_presence.name and current_presence.type == last_presence.type and current_presence.readonly == last_presence.readonly then
      return
    end

    if config.display.show_time and config.timer.reset_on_change then
      discord.set_time()
    end

    local success = discord.update_presence(current_presence.name, current_presence.type, current_presence.readonly, current_presence.cursor, problem_count)
    enabled = true
    if success then
      last_presence = current_presence
    end
  end))
end

function cord.setup(userConfig)
  if vim.g.cord_initialized == nil then
    local timer = vim.loop.new_timer()
    local config = vim.tbl_deep_extend('force', cord.config, userConfig)
    local work = vim.loop.new_async(vim.schedule_wrap(function()
      discord = utils.init(ffi)
      local err = discord.init(
        config.editor.client,
        config.editor.image,
        config.editor.tooltip,
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
        local error = discord.init(
          config.editor.client,
          config.editor.image,
          config.editor.tooltip,
          config.idle.text,
          config.text.viewing,
          config.text.editing,
          config.text.file_browser,
          config.text.plugin_manager,
          config.text.workspace
        )
        if error ~= nil then
          vim.api.nvim_err_writeln('[cord.nvim] Caught unexpected error: ' .. ffi.string(error))
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
          local error = discord.init(
            config.editor.client,
            config.editor.image,
            config.editor.tooltip,
            config.idle.text,
            config.text.viewing,
            config.text.editing,
            config.text.file_browser,
            config.text.plugin_manager,
            config.text.workspace
          )
          if error ~= nil then
            vim.api.nvim_err_writeln('[cord.nvim] Caught unexpected error: ' .. ffi.string(error))
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
