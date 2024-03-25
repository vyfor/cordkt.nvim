@file:Suppress("unused")

package me.blast.cord

import io.github.reblast.kpresence.*
import io.github.reblast.kpresence.rpc.*
import io.github.reblast.kpresence.utils.*
import kotlinx.coroutines.*
import me.blast.cord.mappings.*

private const val GITHUB_ASSETS_URL =
    "https://raw.githubusercontent.com/reblast/cord.nvim/master/assets"
private val scope = CoroutineScope(Dispatchers.IO)
private var richClient: RichClient? = null

// Presence data
private var cwd = ""
private var presenceStartTime: Long? = null
private var repositoryUrl: String? = null
private var clientImage: String? = null
private lateinit var presenceSmallText: String
private lateinit var idleText: String
private lateinit var viewingText: String
private lateinit var editingText: String
private lateinit var fileBrowserText: String
private lateinit var pluginManagerText: String
private lateinit var workspaceText: String

@CName("init")
fun init(
    _client: String,
    _image: String?,
    _presenceSmallText: String,
    _idleText: String,
    _viewingText: String,
    _editingText: String,
    _fileBrowserText: String,
    _pluginManagerText: String,
    _workspaceText: String
): String? {
  richClient =
      when (_client) {
        "vim" -> {
          clientImage = "$GITHUB_ASSETS_URL/editor/vim.png"
          RichClient(1219918645770059796)
        }
        "neovim" -> {
          clientImage = "$GITHUB_ASSETS_URL/editor/neovim.png"
          RichClient(1219918880005165137)
        }
        "lunarvim" -> {
          clientImage = "$GITHUB_ASSETS_URL/editor/lunarvim.png"
          RichClient(1220295374087000104)
        }
        "nvchad" -> {
          clientImage = "$GITHUB_ASSETS_URL/editor/nvchad.png"
          RichClient(1220296082861326378)
        }
        else -> {
          _client.toLongOrNull()?.let {
            clientImage = _image
            RichClient(it)
          }
              ?: return "Passed invalid value to `client`. Must be one of: vim, neovim, lunarvim, nvchad, or a valid client id."
        }
      }

  presenceSmallText = _presenceSmallText
  idleText = _idleText
  viewingText = _viewingText
  editingText = _editingText
  fileBrowserText = _fileBrowserText
  pluginManagerText = _pluginManagerText
  workspaceText = _workspaceText

  scope.launch {
    try {
      withTimeout(30000) { richClient!!.connect() }
    } catch (_: Exception) {}
  }

  return null
}

@CName("update_presence")
fun updatePresence(filename: String, filetype: String, isReadOnly: Boolean): Boolean {
  if (richClient == null || richClient!!.state != State.SENT_HANDSHAKE) return false
  scope.launch {
    try {
      var presenceDetails: String
      var presenceLargeImage: String
      var presenceLargeText: String

      when (filetype) {
        "Cord.idle" -> {
          if (idleText.isBlank()) return@launch
          presenceDetails = idleText
          presenceLargeImage = "$GITHUB_ASSETS_URL/editor/idle.png"
          presenceLargeText = "💤"
        }
        "netrw", "dirvish", "TelescopePrompt" -> {
          if (fileBrowserText.isBlank()) return@launch
          val fileBrowser = fileBrowsers[filetype] ?: return@launch

          presenceDetails = fileBrowserText.replaceFirst("\$s", fileBrowser.second)
          presenceLargeImage = "$GITHUB_ASSETS_URL/file_browser/${fileBrowser.first}.png"
          presenceLargeText = fileBrowser.second
        }
        "lazy", "packer" -> {
          if (pluginManagerText.isBlank()) return@launch
          val pluginManager = pluginManagers[filetype] ?: return@launch

          presenceDetails = pluginManagerText.replaceFirst("\$s", pluginManager.second)
          presenceLargeImage = "$GITHUB_ASSETS_URL/plugin_manager/${pluginManager.first}.png"
          presenceLargeText = pluginManager.second
        }
        else -> {
          if (filename.isBlank()) {
            if (!filetype.isBlank()) return@launch

            presenceDetails =
                (if (isReadOnly) viewingText else editingText).replaceFirst("\$s", "a new file")
            presenceLargeImage = "$GITHUB_ASSETS_URL/language/text.png"
            presenceLargeText = "New buffer"
          } else {
            val language = languages[filetype] ?: ("text" to filetype)

            presenceDetails =
                (if (isReadOnly) viewingText else editingText).replaceFirst("\$s", filename)
            presenceLargeImage = "$GITHUB_ASSETS_URL/language/${language.first}.png"
            presenceLargeText = language.second
          }
        }
      }

      richClient!!.update(
          Activity(
              details = presenceDetails,
              state =
                  workspaceText
                      .takeIf { cwd.isNotBlank() && workspaceText.isNotBlank() }
                      ?.replaceFirst("\$s", cwd),
              assets =
                  ActivityAssets(
                      largeImage = presenceLargeImage,
                      largeText = presenceLargeText,
                      smallImage = clientImage,
                      smallText = presenceSmallText.takeIf { clientImage != null }
                  ),
              timestamps = presenceStartTime?.let { ActivityTimestamps(start = it) },
              buttons =
                  repositoryUrl?.takeIf { url -> url.isNotBlank() }?.let { url ->
                    arrayOf(ActivityButton("View Repository", url))
                  }
          )
      )
    } catch (_: Exception) {}
  }
  return true
}

@CName("clear_presence")
fun clearPresence() {
  presenceStartTime = null
  scope.launch {
    try {
      richClient?.clear()
    } catch (_: Exception) {}
  }
}

@CName("disconnect")
fun disconnect() {
  presenceStartTime = null
  scope.launch {
    try {
      richClient?.shutdown()
    } catch (_: Exception) {}
  }
}

@CName("set_cwd")
fun setCwd(value: String) {
  cwd = value
}

@CName("set_time")
fun setTime() {
  presenceStartTime = epochMillis()
}

@CName("set_repository_url")
fun setRepositoryUrl(value: String) {
  repositoryUrl = value
}
