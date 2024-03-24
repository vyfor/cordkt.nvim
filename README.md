# 🧩 Cord

![cord](https://github.com/reblast/cord.nvim/assets/92883017/bf551310-d073-40ea-abec-7db17b24f2aa)

🚀 **Cord** is a Discord Rich Presence plugin designed for Neovim, written in Kotlin/Native.

## 💎 Features
- Lightweight
- Cross-platform compatibility (Windows, Linux, macOS)*
- Fast startup due to non-blocking, asynchronous nature
- Highly [configurable](https://github.com/reblast/cord.nvim#configuration) in Lua
- Offers a rich icon set for editors, languages, file browsers and plugin managers
- Detects working directory based on VCS files
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
  enable_timer = true,                           -- Enable timer for automatic presence updates
  timer_interval = 1500,                         -- Timer's update interval in milliseconds (min 500)
  show_repository = false,                       -- Display 'View repository' button linked to repository url, if any
  show_time = true,                              -- Display start timestamp
  reset_time_on_change = true,                   -- Reset start timestamp on presence change
  reset_time_on_idle = true,                     -- Reset start timestamp on idle
  editor = 'neovim',                             -- (vim, neovim, lunarvim, nvchad or your application's client id)
  description = 'The Superior Text Editor',      -- Text to display when hovering over the editor's image
  idle = 'Idle',                                 -- Text to display when idle (empty string to disable)
  viewing = 'Viewing $s',                        -- Text to display when viewing a readonly file
  editing = 'Editing $s',                        -- Text to display when editing a file
  file_browser = 'Browsing files in $s',         -- Text to display when browsing files
  plugin_manager = 'Managing packages in $s',    -- Text to display when managing plugins
  workspace = 'In $s',                           -- Text to display when in a workspace (empty string to disable)
})
```

## 🌱 Contributing
This project is in beta. Feel free to open an issue or pull request for missing icons or features.
