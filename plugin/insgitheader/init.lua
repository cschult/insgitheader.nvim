-- create user command 'InsGitHeader'
vim.api.nvim_create_user_command("InsGitHeader", function()
	require("insgitheader").insert_headers()
end, { bang = true, desc = "insert some file info into the top" })

-- create keymap for 'InsGitHeader'
-- vim.keymap.set("n", "<Leader>ii", "<Cmd>InsGitHeader<CR>", { desc = "InsGitHeader }" })
