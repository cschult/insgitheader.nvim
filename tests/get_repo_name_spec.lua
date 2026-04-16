describe("get-repo-name", function()
	local grn
	local original_popen
	local original_getenv

	before_each(function()
		package.loaded["insgitheader.helper.get-repo-name"] = nil
		original_popen = io.popen
		original_getenv = os.getenv
		vim._test.bufname = "/home/user/project/src/file.lua"
	end)

	after_each(function()
		io.popen = original_popen
		os.getenv = original_getenv
	end)

	it("gibt 'name (VCSH)' zurück wenn VCSH_REPO_NAME gesetzt ist", function()
		os.getenv = function(key)
			if key == "VCSH_REPO_NAME" then return "dotfiles" end
			return nil
		end
		grn = require("insgitheader.helper.get-repo-name")
		assert.are.equal("dotfiles (VCSH)", grn.get_repo_name())
	end)

	it("gibt den Git-Toplevel-Pfad zurück für ein normales Repo", function()
		os.getenv = function() return nil end
		local call_count = 0
		io.popen = function(cmd)
			call_count = call_count + 1
			local result = call_count == 1 and "true" or "/home/user/project"
			return {
				read = function(self, fmt) return result end,
				close = function(self) end,
			}
		end
		grn = require("insgitheader.helper.get-repo-name")
		assert.are.equal("/home/user/project", grn.get_repo_name())
	end)

	it("gibt nil zurück wenn nicht in einem Git-Repository", function()
		os.getenv = function() return nil end
		io.popen = function(cmd)
			return {
				read = function(self, fmt) return nil end,
				close = function(self) end,
			}
		end
		grn = require("insgitheader.helper.get-repo-name")
		assert.is_nil(grn.get_repo_name())
	end)
end)
