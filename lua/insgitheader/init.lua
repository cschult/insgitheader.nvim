local M = {}

M.setup = function(opts)
	opts = opts or {}
	vim.api.nvim_create_user_command("InsGitHeader", function()
		local name
		local ggcu = require("insgitheader.helper.get-git-config-user")
		if opts.name then
			name = opts.name
		else
			-- local ggn = require("insgitheader.helper.get-git-user-name")
			name = ggcu.get_git_user("name")
		end
		local email
		if opts.email then
			email = "<" .. opts.email .. ">"
		else
			-- local gge = require("insgitheader.helper.get-git-user-email")
			email = "<" .. ggcu.get_git_user("email") .. ">"
		end
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
		local line3 = cleft .. " author: " .. name .. " " .. email .. " " .. year .. cright
		-- add empty line
		local newline = ""
		-- add on top of file
		vim.api.nvim_buf_set_lines(0, 0, 0, false, { line1, line2, line3, newline })
	end, { bang = true, desc = "insert some file info into the top" })
end
return M
