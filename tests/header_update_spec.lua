describe("header-update", function()
	describe("find_block()", function()
		local fh

		before_each(function()
			package.loaded["insgitheader.helper.find-header"] = nil
			fh = require("insgitheader.helper.find-header")
		end)

		it("should find the block at the start of the file", function()
			local lines = { "-- file: x", "-- git: y", "-- author: z 2024", "", "code" }
			local first, last = fh.find_block(lines, "--")
			assert.are.equal(1, first)
			assert.are.equal(3, last)
		end)

		it("should find the block below prologue and blank line", function()
			local lines = { "#!/bin/sh", "", "# file: x", "# git: y", "# author: z 2024" }
			local first, last = fh.find_block(lines, "#")
			assert.are.equal(3, first)
			assert.are.equal(5, last)
		end)

		it("should not find a block with a different comment character", function()
			local lines = { "-- file: x", "-- git: y", "-- author: z 2024" }
			assert.is_nil(fh.find_block(lines, "#"))
		end)

		it("should not find a block if a line is missing", function()
			local lines = { "-- file: x", "-- author: z 2024" }
			assert.is_nil(fh.find_block(lines, "--"))
		end)

		it("should not find a block below unrelated comment lines", function()
			local lines = { "-- SPDX-License-Identifier: MIT", "-- file: x", "-- git: y", "-- author: z 2024" }
			assert.is_nil(fh.find_block(lines, "--"))
		end)

		it("should detect a prologue line below the block", function()
			local lines = { "# file: x", "# git: y", "# author: z 2024", "", "#!/bin/bash" }
			local _, last = fh.find_block(lines, "#")
			assert.is_true(fh.prolog_below(lines, last))
		end)
	end)

	describe("parse_author()", function()
		local fh

		before_each(function()
			package.loaded["insgitheader.helper.find-header"] = nil
			fh = require("insgitheader.helper.find-header")
		end)

		it("should read a single year", function()
			local year, who, chain = fh.parse_author("-- author: Jane <j@x> 2019")
			assert.are.equal("2019", year)
			assert.are.equal("Jane <j@x>", who)
			assert.is_nil(chain)
		end)

		it("should read the first year of a range", function()
			local year = fh.parse_author("-- author: Jane <j@x> 2019-2024")
			assert.are.equal("2019", year)
		end)

		it("should read an existing chain", function()
			local year, who, chain = fh.parse_author("-- author: Jane <j@x> 2019-2024 (orig. Old <o@y>)")
			assert.are.equal("2019", year)
			assert.are.equal("Jane <j@x>", who)
			assert.are.equal("Old <o@y>", chain)
		end)

		it("should cope with a right comment character", function()
			local year, who = fh.parse_author("/* author: Jane <j@x> 2019 */")
			assert.are.equal("2019", year)
			assert.are.equal("Jane <j@x>", who)
		end)

		it("should read the old format without angle brackets", function()
			local _, who = fh.parse_author("-- author: Jane j@x 2019")
			assert.are.equal("Jane j@x", who)
		end)

		it("should not mistake an email starting with digits for the year", function()
			local year, who = fh.parse_author("# author: cs <12900332+headoop@users.noreply.github.com> 2019")
			assert.are.equal("2019", year)
			assert.are.equal("cs <12900332+headoop@users.noreply.github.com>", who)
		end)

		it("should return no year if there is none", function()
			local year, who = fh.parse_author("-- author: Jane <j@x>")
			assert.is_nil(year)
			assert.is_nil(who)
		end)
	end)

	describe("insert_headers() on an existing header", function()
		local ins
		local original_popen
		local original_getenv
		local original_date

		before_each(function()
			package.loaded["insgitheader"] = nil
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			package.loaded["insgitheader.helper.get-file-name"] = nil
			package.loaded["insgitheader.helper.get-git-config-user"] = nil
			package.loaded["insgitheader.helper.get-repo-name"] = nil
			package.loaded["insgitheader.helper.get-chezmoi"] = nil
			package.loaded["insgitheader.helper.find-header"] = nil

			original_popen = io.popen
			original_getenv = os.getenv
			original_date = os.date

			vim._test.commentstring = "-- %s"
			vim._test.bufname = "/project/src/file.lua"

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
			os.date = function(fmt)
				if fmt == "%Y" then
					return "2026"
				end
				return original_date(fmt)
			end

			ins = require("insgitheader")
			ins.setup({})
		end)

		after_each(function()
			io.popen = original_popen
			os.getenv = original_getenv
			os.date = original_date
		end)

		it("should replace the block instead of creating a second one", function()
			vim._test.reset({
				"-- file: /old/path.lua",
				"-- git: /old/repo",
				"-- author: Test User <test@example.com> 2026",
				"",
				"local x = 1",
			})
			ins.insert_headers()
			assert.are.equal(5, #vim._test.lines)
			assert.are.equal("-- file: /project/src/file.lua", vim._test.lines[1])
			assert.are.equal("-- git: /project", vim._test.lines[2])
			assert.are.equal("local x = 1", vim._test.lines[5])
		end)

		it("should carry the year over into a range", function()
			vim._test.reset({
				"-- file: x",
				"-- git: y",
				"-- author: Test User <test@example.com> 2019",
				"",
			})
			ins.insert_headers()
			assert.are.equal("-- author: Test User <test@example.com> 2019-2026", vim._test.lines[3])
		end)

		it("should not create a range if the year is the same", function()
			vim._test.reset({
				"-- file: x",
				"-- git: y",
				"-- author: Test User <test@example.com> 2026",
				"",
			})
			ins.insert_headers()
			assert.are.equal("-- author: Test User <test@example.com> 2026", vim._test.lines[3])
		end)

		it("should extend an existing range", function()
			vim._test.reset({
				"-- file: x",
				"-- git: y",
				"-- author: Test User <test@example.com> 2019-2024",
				"",
			})
			ins.insert_headers()
			assert.are.equal("-- author: Test User <test@example.com> 2019-2026", vim._test.lines[3])
		end)

		it("should take a foreign previous author into the chain", function()
			vim._test.reset({
				"-- file: x",
				"-- git: y",
				"-- author: Old Name <old@example.com> 2019",
				"",
			})
			ins.insert_headers()
			assert.are.equal(
				"-- author: Test User <test@example.com> 2019-2026 (orig. Old Name <old@example.com>)",
				vim._test.lines[3]
			)
		end)

		it("should append further previous authors to the end of the chain", function()
			vim._test.reset({
				"-- file: x",
				"-- git: y",
				"-- author: Alice <a@x> 2019-2025 (orig. Old Name <old@y>)",
				"",
			})
			ins.insert_headers()
			assert.are.equal(
				"-- author: Test User <test@example.com> 2019-2026 (orig. Old Name <old@y>, Alice <a@x>)",
				vim._test.lines[3]
			)
		end)

		it("should not create a chain if only the format differs", function()
			vim._test.reset({
				"-- file: x",
				"-- git: y",
				"-- author: Test User test@example.com 2019",
				"",
			})
			ins.insert_headers()
			assert.are.equal("-- author: Test User <test@example.com> 2019-2026", vim._test.lines[3])
		end)

		it("should update a block below the shebang", function()
			vim._test.commentstring = "# %s"
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			vim._test.reset({
				"#!/bin/bash",
				"",
				"# file: /alt.sh",
				"# git: /alt",
				"# author: Test User <test@example.com> 2019",
				"",
				"set -e",
			})
			ins.insert_headers()
			assert.are.equal(7, #vim._test.lines)
			assert.are.equal("#!/bin/bash", vim._test.lines[1])
			assert.are.equal("# file: /project/src/file.lua", vim._test.lines[3])
			assert.are.equal(0, #vim._test.notifications)
		end)

		it("should warn if the header sits above the shebang, but update it there", function()
			vim._test.commentstring = "# %s"
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			vim._test.reset({
				"# file: /alt.sh",
				"# git: /alt",
				"# author: Test User <test@example.com> 2019",
				"",
				"#!/bin/bash",
				"set -e",
			})
			ins.insert_headers()
			assert.are.equal(6, #vim._test.lines)
			assert.are.equal("# file: /project/src/file.lua", vim._test.lines[1])
			assert.are.equal("#!/bin/bash", vim._test.lines[5])
			assert.are.equal(1, #vim._test.notifications)
			assert.truthy(vim._test.notifications[1].msg:match("shebang"))
			assert.are.equal(vim.log.levels.WARN, vim._test.notifications[1].level)
		end)

		it("should create a second header if the comment character changed", function()
			vim._test.commentstring = "# %s"
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			vim._test.reset({
				"-- file: x",
				"-- git: y",
				"-- author: Test User <test@example.com> 2019",
				"",
			})
			ins.insert_headers()
			assert.are.equal("# file: /project/src/file.lua", vim._test.lines[1])
			assert.are.equal("-- file: x", vim._test.lines[5])
		end)

		it("should put the cursor on the file: line of the updated block", function()
			vim._test.commentstring = "# %s"
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			vim._test.reset({
				"#!/bin/bash",
				"",
				"# file: /alt.sh",
				"# git: /alt",
				"# author: Test User <test@example.com> 2019",
				"",
				"set -e",
			})
			ins.insert_headers()
			assert.are.same({ 3, 0 }, vim._test.cursor)
		end)
	end)
end)
