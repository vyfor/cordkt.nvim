local function init(ffi)
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
    const char* init(const char*, const char*, const char*, const char*, const char*, const char*, const char*, const char*, const char*, const char*);
    bool update_presence(const char*, const char*, bool, const char*, int);
    void clear_presence();
    void disconnect();
    void set_cwd(const char*);
    void set_time();
    void set_repository_url(const char*);
  ]]

  return ffi.load(new_path)
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

return {
  init = init,
  fetch_repository = fetch_repository,
  find_workspace = find_workspace
}