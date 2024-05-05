local M = {}

function M.get_git_user(item)
	local handle = assert(io.popen("git config user." .. item, "r"))
	local result = handle:read("*l")
	handle:close()
	if result ~= nil then
		-- print(result)
		return result
	else
		if item == "email" then
			-- print("unknown@example.org")
			return "unknown@example.org"
		else
			-- print("unknown")
			return "unknown"
		end
	end
end
return M
