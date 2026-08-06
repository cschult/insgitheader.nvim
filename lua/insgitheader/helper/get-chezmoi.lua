local M = {}

-- Das chezmoi-Source-Dir wechselt innerhalb einer Neovim-Sitzung praktisch nie,
-- jeder Aufruf kostet aber einen Prozessstart. Darum wird einmal gesondiert und
-- das Ergebnis für die restliche Sitzung behalten. Fehlt chezmoi, bleibt
-- source_dir nil und die Erkennung ist damit dauerhaft stillgelegt.
local probed = false
local source_dir = nil
local source_repo = nil

-- Ergebnis des letzten Pfads, damit get-file-name und get-repo-name innerhalb
-- eines :InsGitHeader nicht doppelt nachfragen. Bewusst nur ein Eintrag: so
-- bleibt die Antwort über Aufrufe hinweg frisch, falls du zwischendurch
-- `chezmoi add` benutzt.
local last_path = nil
local last_result = nil

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
	if probed then
		return
	end
	probed = true
	source_dir = popen_line("chezmoi source-path")
	if source_dir then
		source_repo = popen_line("cd " .. sh_quote(source_dir) .. " && git rev-parse --show-toplevel")
	end
end

-- Verwirft alle Caches. Wird von den Tests gebraucht.
function M.reset()
	probed = false
	source_dir = nil
	source_repo = nil
	last_path = nil
	last_result = nil
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
		-- es ein echter chezmoi-Eintrag und der Zielpfad belastbar.
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

-- Liefert is_chezmoi, repo, target_path.
--   repo         Git-Root des chezmoi-Source-Dirs (nil, falls kein Git-Repo)
--   target_path  gesetzt nur für Quelldateien mit gültigem Round-Trip
function M.lookup(path)
	if not path or path == "" then
		return false
	end
	if path ~= last_path then
		last_path = path
		last_result = { uncached_lookup(path) }
	end
	return last_result[1], last_result[2], last_result[3]
end

return M
