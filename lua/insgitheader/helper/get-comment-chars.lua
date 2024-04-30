local M = {}

function M.get_comment_chars()
	local buffer_number = vim.api.nvim_get_current_buf()
	local commentstring = vim.api.nvim_get_option_value("commentstring", { buf = buffer_number })
	-- local comments = vim.api.nvim_get_option_value('comments', { buf = buffer_number })
	local t = {}
	local sep = "%%s"
	for str in string.gmatch(commentstring, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	local cleft = t[1]
	local cright = ""
	if t[2] then
		cright = t[2]
	end
	return cleft, cright
end

return M
