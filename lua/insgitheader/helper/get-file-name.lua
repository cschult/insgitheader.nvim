local M = {}

-- TODO: return complete path + filename if vcsh repo,
-- else return path + filname relativ to the git working dir
function M.get_file_name()
	local bufname = vim.api.nvim_buf_get_name(0)
	-- local filename = bufname:match("^.+/(.+)$")

	-- return filename
	return bufname
end

return M
