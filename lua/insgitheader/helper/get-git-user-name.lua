local M = {}

function M.get_git_user_name()
	local handle = assert(io.popen("git config user.name", "r"))
	local result = handle:read("*l")
	handle:close()
	if result then
		return result
	else
		return ""
	end
end

return M
