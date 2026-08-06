local M = {}

local chezmoi = require("insgitheader.helper.get-chezmoi")

-- Für chezmoi-Quelldateien wird der Zielpfad ausgewiesen statt des Quellpfads.
-- Damit ist der Header in Quelle und Ziel byte-identisch und `chezmoi apply`
-- erzeugt an dieser Stelle keinen Diff.
--
-- `mode` ist "full" (Vorgabe) für Pfad plus Dateiname oder "basename" für nur
-- den Dateinamen. Bei chezmoi-Quelldateien wird der Basename aus dem Zielpfad
-- genommen, damit Quelle und Ziel auch hier dieselbe Zeile bekommen.
function M.get_file_name(mode)
	local bufname = vim.api.nvim_buf_get_name(0)
	local is_chezmoi, _, target = chezmoi.lookup(bufname)
	local name = (is_chezmoi and target) and target or bufname
	if mode == "basename" then
		return name:match("[^/]+$") or name
	end
	return name
end

return M
