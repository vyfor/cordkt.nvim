# 🧩 Cord

![cord_banner](https://github.com/reblast/cord.nvim/assets/92883017/d83f76d8-e6e3-4b39-86c4-398a5260cf6e)

🚀 **Cord** is a Discord Rich Presence plugin designed for Neovim, written in Kotlin/Native.

## 💎 Features
- Lightweight
- Cross-platform compatibility (Windows, Linux, macOS)*
- Fast startup due to non-blocking, asynchronous nature
- Highly [configurable](https://github.com/reblast/cord.nvim#-configuration) in Lua
- Offers a rich icon set for various components
- Automatically detects working directory based on VCS files as well as the Git repository
- Identifies problems across active buffers
- Supports configurable idle status detection
- Respects the ratelimit of one update per 15 seconds
- Written in native code, uses Lua FFI for integration

> \* Please note that the plugin has only been tested on Windows.

## 🔌 Requirements
- Neovim compiled with LuaJIT

## 📦 Installation
<details>
  <summary>lazy.nvim</summary>

  ```lua
  {
    'reblast/cord.nvim',
    build = './gradlew linkReleaseSharedNative --no-daemon --no-build-cache'
  }
  ```

  If the build fails with message `Process was killed because it reached the timeout`, try increasing the timeout in Lazy's configuration:
  
  ```lua
  require('lazy').setup(..., {
    git = {
      timeout = 600
    }
  })
  ```
</details>

<details>
  <summary>pckr.nvim</summary>

  ```lua
  {
    'reblast/cord.nvim',
    run = './gradlew linkReleaseSharedNative --no-daemon --no-build-cache'
  }
  ```
</details>

<details>
  <summary>other</summary>
  <p>Same steps apply to other plugin managers. Just make sure to add/run this build command:</p>

  ```sh
  ./gradlew linkReleaseSharedNative --no-daemon --no-build-cache
  ```
</details>

## 🔧 Configuration
```lua
require('cord').setup({
  usercmds = true,                              -- Enable user commands
  timer = {
    enable = true,                              -- Enable timer
    interval = 1500,                            -- Timer's update interval in milliseconds (min 500)
    reset_on_idle = false,                      -- Reset start timestamp on idle
    reset_on_change = false,                    -- Reset start timestamp on presence change
  },
  editor = {
    image = nil,                                -- Image ID or URL in case a custom client id is provided
    client = 'neovim',                          -- vim, neovim, lunarvim, nvchad or your application's client id
    tooltip = 'The Superior Text Editor',       -- Text to display when hovering over the editor's image
  },
  display = {
    show_time = true,                           -- Display start timestamp
    show_repository = true,                     -- Display 'View repository' button linked to repository url, if any
    show_cursor_position = true,                -- Display line and column number of cursor's position
  },
  lsp = {
    show_problem_count = false,                 -- Display number of diagnostics problems
    severity = 1,                               -- 1 = Error, 2 = Warning, 3 = Info, 4 = Hint
    scope = 'workspace',                        -- buffer or workspace
  }
  idle = {
    show_idle = true,                           -- Enable idle status
    timeout = 300000,                           -- Timeout in milliseconds after which the idle status is set, 0 to display immediately
    disable_on_focus = true,                    -- Do not display idle status when neovim is focused
    text = 'Idle',                              -- Text to display when idle
    tooltip = '💤',                             -- Text to display when hovering over the idle image
  },
  text = {
    viewing = 'Viewing $s',                     -- Text to display when viewing a readonly file
    editing = 'Editing $s',                     -- Text to display when editing a file
    file_browser = 'Browsing files in $s',      -- Text to display when browsing files (Empty string to disable)
    plugin_manager = 'Managing plugins in $s',  -- Text to display when managing plugins (Empty string to disable)
    workspace = 'In $s',                        -- Text to display when in a workspace (Empty string to disable)
  }
})
```

### ⌨️ User commands (WIP)
- `:DiscordInit`     - Initialize presence client internally and connect to Discord
- `:DiscordShow`     - Start presence timer
- `:DiscordHide`     - Clear presence and stop timer
- `:DiscordToggle`   - Toggle presence
- `:DiscordRestart`  - Attempt to reconnect to Discord
- `:DiscordShutdown` - Disconnect from Discord

## 🌱 Contributing
This project is in beta. Feel free to open an issue or pull request for missing icons or features. You can also contact me on Discord **[poxuizm](https://discord.com/users/446729269872427018)** if you have any questions.
