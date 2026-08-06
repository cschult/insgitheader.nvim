-- create user command 'InsGitHeader'
vim.api.nvim_create_user_command("InsGitHeader", function()
	require("insgitheader").insert_headers()
end, { bang = true, desc = "insert some file info into the top" })

-- Das chezmoi-Ergebnis wird pro Buffer gemerkt. Wechselt der Buffer seinen
-- Namen (BufFilePost bei :saveas oder :file) oder wird er geschrieben
-- (BufWritePost), ist es nicht mehr belastbar und wird verworfen.
vim.api.nvim_create_autocmd({ "BufFilePost", "BufWritePost" }, {
	group = vim.api.nvim_create_augroup("InsGitHeader", { clear = true }),
	desc = "drop the cached chezmoi lookup for this buffer",
	callback = function(args)
		require("insgitheader.helper.get-chezmoi").invalidate(args.buf)
	end,
})

-- create keymap for 'InsGitHeader'
-- vim.keymap.set("n", "<Leader>ii", "<Cmd>InsGitHeader<CR>", { desc = "InsGitHeader }" })
