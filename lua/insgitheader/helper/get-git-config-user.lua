local M = {}

function M.get_git_user(item)
	local handle = assert(io.popen("git config user." .. item, "r"))
	local result = handle:read("*l")
	handle:close()
	if result then
		return result
	else
		return ""
	end
end

return M
