-- create user command 'InsGitHeader'
vim.api.nvim_create_user_command("InsGitHeader", function()
	require("insgitheader").insert_headers()
end, { bang = true, desc = "insert some file info into the top" })

-- The chezmoi result is cached per buffer. If the buffer changes its name
-- (BufFilePost on :saveas or :file) or is written (BufWritePost), the result
-- is no longer reliable and gets dropped.
vim.api.nvim_create_autocmd({ "BufFilePost", "BufWritePost" }, {
	group = vim.api.nvim_create_augroup("InsGitHeader", { clear = true }),
	desc = "drop the cached chezmoi lookup for this buffer",
	callback = function(args)
		require("insgitheader.helper.get-chezmoi").invalidate(args.buf)
	end,
})

-- create keymap for 'InsGitHeader'
-- vim.keymap.set("n", "<Leader>ii", "<Cmd>InsGitHeader<CR>", { desc = "InsGitHeader }" })
