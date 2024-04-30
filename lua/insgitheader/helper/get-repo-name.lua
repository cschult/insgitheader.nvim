local M = {}

function M.get_repo_name()
	local vcsh_repo_name = os.getenv("VCSH_REPO_NAME")
	if vcsh_repo_name then
		-- this is a vcsh managed bare repo
		return vcsh_repo_name .. " (VCSH)"
	else
		local repo = ""
		local bufname = vim.api.nvim_buf_get_name(0)
		local path = bufname:match("^.+/+")
		local handle
		if path then
			handle = io.popen("cd " .. path .. " && git rev-parse --is-inside-work-tree 2>/dev/null")
		end
		if handle then
			local is_inside_work_tree = handle:read("*l")
			handle:close()
			if is_inside_work_tree == "true" then
				-- we are in a git dir
				handle = io.popen("cd " .. path .. " && git rev-parse --show-toplevel")
				if handle then
					repo = handle:read("*l")
					handle:close()
				end
				return repo
			elseif is_inside_work_tree == "false" then
				-- we are in the .git dir
				handle = io.popen("cd " .. path:sub(1, -5) .. " && git rev-parse --show-toplevel")
				if handle then
					repo = handle:read("*l")
					handle:close()
					return repo
				end
			else
				-- we ar not in a git dir
				return
			end
		end
	end
end

return M
