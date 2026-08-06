local M = {}

-- Name of the buffer variable holding the per-buffer result. It dies with the
-- buffer, so no cleanup autocommand is needed, and it can be inspected for
-- diagnostics with :echo b:insgitheader_chezmoi.
local BUF_VAR = "insgitheader_chezmoi"

-- The source directory is a global chezmoi setting and is kept for the
-- session. A failed probe is deliberately not pinned down: chezmoi can be
-- installed in the middle of a session.
local source_dir = nil
local source_repo = nil

local function sh_quote(s)
	return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

local function popen_line(cmd)
	local handle = io.popen(cmd .. " 2>/dev/null")
	if not handle then
		return nil
	end
	local line = handle:read("*l")
	handle:close()
	if line == nil or line == "" then
		return nil
	end
	return line
end

local function probe()
	if source_dir then
		return
	end
	source_dir = popen_line("chezmoi source-path")
	if source_dir then
		source_repo = popen_line("cd " .. sh_quote(source_dir) .. " && git rev-parse --show-toplevel")
	end
end

-- Drops the session cache. The buffer caches are untouched by this, they sit
-- on the buffers themselves. Used by the tests.
function M.reset()
	source_dir = nil
	source_repo = nil
end

-- Drops the result for a single buffer. Hooked up in plugin/ to BufFilePost
-- and BufWritePost.
function M.invalidate(bufnr)
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.b[bufnr][BUF_VAR] = nil
	end
end

local function uncached_lookup(path)
	probe()
	if not source_dir then
		return false
	end

	if path:sub(1, #source_dir + 1) == source_dir .. "/" then
		-- Source file. `chezmoi target-path` is a pure path transformation and
		-- answers for README.md or .git/config in the source directory as well.
		-- Hence the round-trip: only if source-path points back at exactly this
		-- file is it a real chezmoi entry and the target path reliable. For a file
		-- not written to disk yet target-path fails; after the first :w the buffer
		-- cache is dropped and the resolution succeeds.
		local target = popen_line("chezmoi target-path " .. sh_quote(path))
		if target and popen_line("chezmoi source-path " .. sh_quote(target)) == path then
			return true, source_repo, target
		end
		return true, source_repo
	end

	-- Target file: managed if chezmoi knows a source file for it.
	if popen_line("chezmoi source-path " .. sh_quote(path)) then
		return true, source_repo
	end
	return false
end

-- Returns is_chezmoi, repo, target_path for buffer `bufnr` (0 = current one).
--   repo         git root of the chezmoi source directory (nil if no git repo)
--   target_path  set only for source files with a valid round-trip
--
-- The result is cached on the buffer, positive as well as negative. The path
-- stored alongside it makes the entry self-invalidating: if the buffer name
-- changes without an event firing, the entry counts as a miss.
function M.lookup(bufnr)
	bufnr = bufnr or 0
	if bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf()
	end
	local path = vim.api.nvim_buf_get_name(bufnr)

	local cached = vim.b[bufnr][BUF_VAR]
	if cached and cached.path == path then
		return cached.is_chezmoi, cached.repo, cached.target
	end

	local is_chezmoi, repo, target = false, nil, nil
	if path ~= "" then
		is_chezmoi, repo, target = uncached_lookup(path)
	end

	vim.b[bufnr][BUF_VAR] = {
		path = path,
		is_chezmoi = is_chezmoi,
		repo = repo,
		target = target,
	}
	return is_chezmoi, repo, target
end

return M
