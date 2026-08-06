local M = {}

local chezmoi = require("insgitheader.helper.get-chezmoi")

-- Returns repo, is_chezmoi.
function M.get_repo_name()
	local vcsh_repo_name = os.getenv("VCSH_REPO_NAME")
	if vcsh_repo_name then
		-- this is a vcsh managed bare repo
		return vcsh_repo_name .. " (VCSH)", false
	end

	local bufname = vim.api.nvim_buf_get_name(0)

	-- Ask before git: source files do sit in a git repo but should still be
	-- reported as chezmoi, and target files sit in none at all. In both cases
	-- the repo is the one of the chezmoi source directory.
	local is_chezmoi, chezmoi_repo = chezmoi.lookup(0)
	if is_chezmoi then
		return chezmoi_repo, true
	end

	local repo = ""
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
			return repo, false
		elseif is_inside_work_tree == "false" then
			-- we are in the .git dir
			handle = io.popen("cd " .. path:sub(1, -5) .. " && git rev-parse --show-toplevel")
			if handle then
				repo = handle:read("*l")
				handle:close()
				return repo, false
			end
		else
			-- we are not in a git dir
			return nil, false
		end
	end
	return nil, false
end

return M
