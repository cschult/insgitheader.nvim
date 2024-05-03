local M = {}

function M.get_git_user_email()
	local handle = assert(io.popen("git config user.email", "r"))
	local result = handle:read("*l")
	handle:close()
	if result then
		return result
	else
		return ""
	end
end

return M
