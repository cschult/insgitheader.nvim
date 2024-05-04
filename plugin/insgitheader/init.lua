local M = {}

M.keys = function()
	vim.keymap.set("n", "<Leader>ii", "<Cmd>InsGitHeader", { desc = "InsGitHeader }" })
end

return M
