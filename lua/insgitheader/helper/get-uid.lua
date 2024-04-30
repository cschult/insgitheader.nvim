local M = {}

function M.get_uid()
	local out = io.popen("id -u")
	if out then
		local uid = out:read("*l")
		out:close()
		return uid
	end
end

return M
