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

	it("gibt den konfigurierten Git-Benutzernamen zurück", function()
		mock_popen("Ada Lovelace")
		ggc = require("insgitheader.helper.get-git-config-user")
		assert.are.equal("Ada Lovelace", ggc.get_git_user("name"))
	end)

	it("gibt die konfigurierte Git-E-Mail zurück", function()
		mock_popen("ada@example.com")
		ggc = require("insgitheader.helper.get-git-config-user")
		assert.are.equal("ada@example.com", ggc.get_git_user("email"))
	end)

	it("gibt 'unknown' zurück wenn kein Name konfiguriert", function()
		mock_popen(nil)
		ggc = require("insgitheader.helper.get-git-config-user")
		assert.are.equal("unknown", ggc.get_git_user("name"))
	end)

	it("gibt 'unknown@example.org' zurück wenn keine E-Mail konfiguriert", function()
		mock_popen(nil)
		ggc = require("insgitheader.helper.get-git-config-user")
		assert.are.equal("unknown@example.org", ggc.get_git_user("email"))
	end)
end)
