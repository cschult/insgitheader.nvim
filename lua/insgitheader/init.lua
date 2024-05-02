local M = {}

function M.setup(opts)
	-- TODO: add a helper file to get name and email from git config
	-- TODO: else get name and email from setup option
	-- TODO: add a switch if git or setup shall be used to get name and email
	opts = opts or {}
	vim.api.nvim_create_user_command("InsGitHeader", function()
		-- get comment signs
		local cleft, cright
		local gcc = require("insgitheader.helper.get-comment-chars")
		cleft, cright = gcc.get_comment_chars()
		if cright ~= "" then
			cright = " " .. cright
		end
		if not cleft then
			cleft = "#"
		end
		-- get file name
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
		-- set author name
		local year = os.date("%Y")
		local line3 = cleft .. " author: Christian Schult <cschult@devmem.de> " .. year .. cright
		-- add empty line
		local newline = ""
		-- add on top of file
		vim.api.nvim_buf_set_lines(0, 0, 0, false, { line1, line2, line3, newline })
	end, { bang = true, desc = "insert some file info into the top" })
end

return M
