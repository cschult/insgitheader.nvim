describe("insgitheader", function()
	local ins
	local original_popen
	local original_getenv

	before_each(function()
		-- Drop all cached modules
		package.loaded["insgitheader"] = nil
		package.loaded["insgitheader.helper.get-comment-chars"] = nil
		package.loaded["insgitheader.helper.get-file-name"] = nil
		package.loaded["insgitheader.helper.get-git-config-user"] = nil
		package.loaded["insgitheader.helper.get-repo-name"] = nil
		package.loaded["insgitheader.helper.get-chezmoi"] = nil
		package.loaded["insgitheader.helper.find-header"] = nil

		original_popen = io.popen
		original_getenv = os.getenv

		vim._test.commentstring = "-- %s"
		vim._test.bufname = "/project/src/file.lua"
		vim._test.reset({ "local x = 1" })

		-- io.popen mock: answers the individual git commands. chezmoi is not
		-- installed here, that is covered by its own block further down.
		io.popen = function(cmd)
			local result
			if cmd:match("^chezmoi") then
				result = nil
			elseif cmd:match("git config user%.name") then
				result = "Test User"
			elseif cmd:match("git config user%.email") then
				result = "test@example.com"
			elseif cmd:match("is%-inside%-work%-tree") then
				result = "true"
			elseif cmd:match("show%-toplevel") then
				result = "/project"
			end
			return {
				read = function(self, fmt)
					return result
				end,
				close = function(self) end,
			}
		end

		os.getenv = function()
			return nil
		end

		ins = require("insgitheader")
	end)

	after_each(function()
		io.popen = original_popen
		os.getenv = original_getenv
	end)

	describe("setup()", function()
		it("should override the author name", function()
			ins.setup({ name = "Jane Doe", email = "jane@example.com" })
			ins.insert_headers()
			assert.truthy(vim._test.lines[3]:match("Jane Doe"))
		end)

		it("should override the email address", function()
			ins.setup({ name = "Jane Doe", email = "jane@example.com" })
			ins.insert_headers()
			assert.truthy(vim._test.lines[3]:match("jane@example%.com"))
		end)

		it("should leave name and email unchanged if opts is empty", function()
			ins.setup({})
			ins.insert_headers()
			assert.truthy(vim._test.lines[3]:match("Test User"))
			assert.truthy(vim._test.lines[3]:match("test@example%.com"))
		end)

		it("should write the full path by default", function()
			ins.setup({})
			ins.insert_headers()
			assert.are.equal("-- file: /project/src/file.lua", vim._test.lines[1])
		end)

		it("should write only the file name with path='basename'", function()
			ins.setup({ path = "basename" })
			ins.insert_headers()
			assert.are.equal("-- file: file.lua", vim._test.lines[1])
		end)

		it("should write the full path with path='full'", function()
			ins.setup({ path = "full" })
			ins.insert_headers()
			assert.are.equal("-- file: /project/src/file.lua", vim._test.lines[1])
		end)

		it("should warn on an unknown path value and keep the default", function()
			ins.setup({ path = "relative" })
			ins.insert_headers()
			assert.are.equal(1, #vim._test.notifications)
			assert.truthy(vim._test.notifications[1].msg:match("unknown path option"))
			assert.are.equal(vim.log.levels.WARN, vim._test.notifications[1].level)
			assert.are.equal("-- file: /project/src/file.lua", vim._test.lines[1])
		end)

		it("should update an existing header to path='basename'", function()
			vim._test.reset({
				"-- file: /project/src/file.lua",
				"-- git: /project",
				"-- author: Test User <test@example.com> 2026",
				"",
			})
			ins.setup({ path = "basename" })
			ins.insert_headers()
			assert.are.equal("-- file: file.lua", vim._test.lines[1])
			assert.are.equal(4, #vim._test.lines)
		end)
	end)

	describe("insert_headers()", function()
		before_each(function()
			ins.setup({})
		end)

		it("should insert exactly 4 lines (3 header + blank line)", function()
			ins.insert_headers()
			assert.are.equal(4, #vim._test.set_lines)
		end)

		it("should put the file name in the first line", function()
			ins.insert_headers()
			assert.truthy(vim._test.lines[1]:match("file%.lua"))
		end)

		it("should start the first line with the comment character", function()
			ins.insert_headers()
			assert.truthy(vim._test.lines[1]:match("^%-%-"))
		end)

		it("should put the repo path in the second line", function()
			ins.insert_headers()
			assert.truthy(vim._test.lines[2]:match("/project"))
		end)

		it("should put the current year in the third line", function()
			ins.insert_headers()
			local year = tostring(os.date("%Y"))
			assert.truthy(vim._test.lines[3]:match(year))
		end)

		it("should put the email in angle brackets", function()
			ins.insert_headers()
			assert.truthy(vim._test.lines[3]:match("<test@example%.com>"))
		end)

		it("should leave the fourth line blank", function()
			ins.insert_headers()
			assert.are.equal("", vim._test.lines[4])
		end)

		it("should leave the rest of the buffer content in place", function()
			ins.insert_headers()
			assert.are.equal("local x = 1", vim._test.lines[5])
		end)

		it("should use the right comment character for block comments", function()
			vim._test.commentstring = "/* %s */"
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			ins.insert_headers()
			assert.truthy(vim._test.lines[1]:match("%*/$"))
		end)

		it("should fall back to '#' if no commentstring is set", function()
			vim._test.commentstring = ""
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			ins.insert_headers()
			assert.truthy(vim._test.lines[1]:match("^#"))
		end)

		it("should not double an existing blank line at the end of the block", function()
			vim._test.reset({ "", "local x = 1" })
			ins.insert_headers()
			assert.are.equal(3, #vim._test.set_lines)
			assert.are.equal("", vim._test.lines[4])
			assert.are.equal("local x = 1", vim._test.lines[5])
		end)

		it("should put the cursor on the file: line", function()
			ins.insert_headers()
			assert.are.same({ 1, 0 }, vim._test.cursor)
		end)

		it("should leave the git line empty if no repo is found", function()
			io.popen = function(cmd)
				local result
				if cmd:match("git config user%.name") then
					result = "Test User"
				elseif cmd:match("git config user%.email") then
					result = "test@example.com"
				end
				return {
					read = function(self, fmt)
						return result
					end,
					close = function(self) end,
				}
			end
			package.loaded["insgitheader.helper.get-repo-name"] = nil
			package.loaded["insgitheader.helper.get-chezmoi"] = nil
			ins.insert_headers()
			assert.are.equal("--", vim._test.lines[2])
		end)
	end)
end)
