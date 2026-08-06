local M = {}

-- Name der Buffer-Variable, in der das Ergebnis pro Buffer liegt. Sie stirbt
-- mit dem Buffer, darum braucht es kein Aufräum-Autocmd, und sie lässt sich
-- zur Diagnose mit :echo b:insgitheader_chezmoi ansehen.
local BUF_VAR = "insgitheader_chezmoi"

-- Das Source-Dir ist eine globale chezmoi-Einstellung und wird für die
-- Sitzung behalten. Ein Fehlversuch wird bewusst nicht festgeschrieben:
-- chezmoi kann mitten in der Sitzung installiert werden.
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

-- Verwirft den Sitzungs-Cache. Die Buffer-Caches bleiben davon unberührt,
-- die hängen an den Buffern selbst. Wird von den Tests gebraucht.
function M.reset()
	source_dir = nil
	source_repo = nil
end

-- Verwirft das Ergebnis eines einzelnen Buffers. Hängt in plugin/ an
-- BufFilePost und BufWritePost.
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
		-- Quelldatei. `chezmoi target-path` ist eine reine Pfadtransformation und
		-- antwortet auch für README.md oder .git/config im Source-Dir. Deshalb der
		-- Round-Trip: nur wenn source-path wieder auf genau diese Datei zeigt, ist
		-- es ein echter chezmoi-Eintrag und der Zielpfad belastbar. Für eine noch
		-- nicht geschriebene Datei scheitert target-path; nach dem ersten :w wird
		-- der Buffer-Cache verworfen und die Auflösung gelingt.
		local target = popen_line("chezmoi target-path " .. sh_quote(path))
		if target and popen_line("chezmoi source-path " .. sh_quote(target)) == path then
			return true, source_repo, target
		end
		return true, source_repo
	end

	-- Target-Datei: verwaltet, wenn chezmoi eine Quelldatei dazu kennt.
	if popen_line("chezmoi source-path " .. sh_quote(path)) then
		return true, source_repo
	end
	return false
end

-- Liefert is_chezmoi, repo, target_path für den Buffer `bufnr` (0 = aktueller).
--   repo         Git-Root des chezmoi-Source-Dirs (nil, falls kein Git-Repo)
--   target_path  gesetzt nur für Quelldateien mit gültigem Round-Trip
--
-- Das Ergebnis wird am Buffer gemerkt, positiv wie negativ. Der mitgespeicherte
-- Pfad macht den Eintrag selbstinvalidierend: wechselt der Buffer-Name, ohne
-- dass ein Event gefeuert hat, gilt er als Fehltreffer.
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
