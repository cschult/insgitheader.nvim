local M = {}

local chezmoi = require("insgitheader.helper.get-chezmoi")

-- For chezmoi source files the target path is shown instead of the source
-- path. That makes the header byte-identical in source and target, so
-- `chezmoi apply` produces no diff at this spot.
--
-- `mode` is "full" (the default) for path plus file name, or "basename" for
-- the file name only. For chezmoi source files the basename is taken from the
-- target path, so that source and target get the same line here as well.
function M.get_file_name(mode)
	local bufname = vim.api.nvim_buf_get_name(0)
	local is_chezmoi, _, target = chezmoi.lookup(0)
	local name = (is_chezmoi and target) and target or bufname
	if mode == "basename" then
		return name:match("[^/]+$") or name
	end
	return name
end

return M
