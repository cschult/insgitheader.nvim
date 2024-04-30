local M = {}

function M.setup(opts)
	opts = opts or {}
	vim.keymap.set("n", "<leader>H", function()
		-- 1. Kommentarzeichen festlegen
		local cleft, cright
		local gcc = require("insgitheader.helper.get-comment-chars")
		cleft, cright = gcc.get_comment_chars()
		if cright ~= "" then
			-- if cright then
			cright = " " .. cright
		end
		if not cleft then
			cleft = "#"
		end
		-- 2. Dateinamen festlegen
		local gfn = require("insgitheader.helper.get-file-name")
		local fname = gfn.get_file_name()
		local line1 = cleft .. " file: " .. fname .. cright
		-- 3. Repo-Namen festlegen
		local grn = require("insgitheader.helper.get-repo-name")
		local repo = grn.get_repo_name()
		local line2
		if repo then
			line2 = cleft .. " git: " .. repo .. cright
		else
			line2 = cleft .. cright
		end
		-- 4. Autor-Zeile festlegen
		local year = os.date("%Y")
		local line3 = cleft .. " author: Christian Schult <cschult@devmem.de> " .. year .. cright
		-- empty line
		local newline = ""
		-- 5. alles ausgeben auf mehreren Zeilen
		vim.api.nvim_buf_set_lines(0, 0, 0, false, { line1, line2, line3, newline })
	end, { desc = "insert some file info into the top" })
end

return M
