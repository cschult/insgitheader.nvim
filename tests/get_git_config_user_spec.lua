describe("get-git-config-user", function()
	local ggc
	local original_popen

	before_each(function()
		package.loaded["insgitheader.helper.get-git-config-user"] = nil
		original_popen = io.popen
	end)

	after_each(function()
		io.popen = original_popen
	end)

	local function mock_popen(result)
		io.popen = function(cmd, mode)
			return {
				read = function(self, fmt) return result end,
				close = function(self) end,
			}
		end
	end

	it("should return the configured git user name", function()
		mock_popen("Ada Lovelace")
		ggc = require("insgitheader.helper.get-git-config-user")
		assert.are.equal("Ada Lovelace", ggc.get_git_user("name"))
	end)

	it("should return the configured git email", function()
		mock_popen("ada@example.com")
		ggc = require("insgitheader.helper.get-git-config-user")
		assert.are.equal("ada@example.com", ggc.get_git_user("email"))
	end)

	it("should return 'unknown' if no name is configured", function()
		mock_popen(nil)
		ggc = require("insgitheader.helper.get-git-config-user")
		assert.are.equal("unknown", ggc.get_git_user("name"))
	end)

	it("should return 'unknown@example.org' if no email is configured", function()
		mock_popen(nil)
		ggc = require("insgitheader.helper.get-git-config-user")
		assert.are.equal("unknown@example.org", ggc.get_git_user("email"))
	end)
end)
