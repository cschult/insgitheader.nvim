local M = {}

local chezmoi = require("insgitheader.helper.get-chezmoi")

-- Für chezmoi-Quelldateien wird der Zielpfad ausgewiesen statt des Quellpfads.
-- Damit ist der Header in Quelle und Ziel byte-identisch und `chezmoi apply`
-- erzeugt an dieser Stelle keinen Diff.
function M.get_file_name()
	local bufname = vim.api.nvim_buf_get_name(0)
	local is_chezmoi, _, target = chezmoi.lookup(bufname)
	if is_chezmoi and target then
		return target
	end
	return bufname
end

return M
