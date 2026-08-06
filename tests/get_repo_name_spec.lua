describe("get-repo-name", function()
	local grn
	local original_popen
	local original_getenv

	-- Builds an io.popen mock from a list of {pattern, answer} pairs.
	-- The first matching pattern wins; without a match nil is returned.
	local function popen_mock(rules)
		return function(cmd)
			local result
			for _, rule in ipairs(rules) do
				if cmd:match(rule[1]) then
					result = rule[2]
					break
				end
			end
			return {
				read = function(self, fmt)
					return result
				end,
				close = function(self) end,
			}
		end
	end

	before_each(function()
		package.loaded["insgitheader.helper.get-repo-name"] = nil
		package.loaded["insgitheader.helper.get-chezmoi"] = nil
		-- The chezmoi cache sits on the buffers, not on the module
		vim._test.buffer_vars = {}
		original_popen = io.popen
		original_getenv = os.getenv
		os.getenv = function()
			return nil
		end
		vim._test.bufname = "/home/user/project/src/file.lua"
	end)

	after_each(function()
		io.popen = original_popen
		os.getenv = original_getenv
	end)

	it("should return 'name (VCSH)' if VCSH_REPO_NAME is set", function()
		os.getenv = function(key)
			if key == "VCSH_REPO_NAME" then
				return "dotfiles"
			end
			return nil
		end
		grn = require("insgitheader.helper.get-repo-name")
		local repo, is_chezmoi = grn.get_repo_name()
		assert.are.equal("dotfiles (VCSH)", repo)
		assert.is_false(is_chezmoi)
	end)

	it("should return the git toplevel path for a normal repo", function()
		io.popen = popen_mock({
			{ "^chezmoi", nil },
			{ "is%-inside%-work%-tree", "true" },
			{ "show%-toplevel", "/home/user/project" },
		})
		grn = require("insgitheader.helper.get-repo-name")
		local repo, is_chezmoi = grn.get_repo_name()
		assert.are.equal("/home/user/project", repo)
		assert.is_false(is_chezmoi)
	end)

	it("should return nil if not inside a git repository", function()
		io.popen = popen_mock({})
		grn = require("insgitheader.helper.get-repo-name")
		local repo, is_chezmoi = grn.get_repo_name()
		assert.is_nil(repo)
		assert.is_false(is_chezmoi)
	end)

	describe("chezmoi", function()
		local SRC = "/home/user/.local/share/chezmoi"

		it("should mark a managed target file", function()
			vim._test.bufname = "/home/user/.bashrc"
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi source%-path ", SRC .. "/dot_bashrc.tmpl" },
				{ "show%-toplevel", SRC },
			})
			grn = require("insgitheader.helper.get-repo-name")
			local repo, is_chezmoi = grn.get_repo_name()
			assert.are.equal(SRC, repo)
			assert.is_true(is_chezmoi)
		end)

		it("should mark a source file in the source directory", function()
			vim._test.bufname = SRC .. "/dot_bashrc.tmpl"
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi target%-path ", "/home/user/.bashrc" },
				{ "^chezmoi source%-path ", SRC .. "/dot_bashrc.tmpl" },
				{ "show%-toplevel", SRC },
			})
			grn = require("insgitheader.helper.get-repo-name")
			local repo, is_chezmoi = grn.get_repo_name()
			assert.are.equal(SRC, repo)
			assert.is_true(is_chezmoi)
		end)

		it("should mark a file in the source directory without a valid round-trip too", function()
			vim._test.bufname = SRC .. "/README.md"
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi target%-path ", "/home/user/README.md" },
				{ "^chezmoi source%-path ", nil },
				{ "show%-toplevel", SRC },
			})
			grn = require("insgitheader.helper.get-repo-name")
			local repo, is_chezmoi = grn.get_repo_name()
			assert.are.equal(SRC, repo)
			assert.is_true(is_chezmoi)
		end)

		it("should not mark an unmanaged file", function()
			vim._test.bufname = "/home/user/project/src/file.lua"
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi source%-path ", nil },
				{ "is%-inside%-work%-tree", "true" },
				{ "show%-toplevel", "/home/user/project" },
			})
			grn = require("insgitheader.helper.get-repo-name")
			local repo, is_chezmoi = grn.get_repo_name()
			assert.are.equal("/home/user/project", repo)
			assert.is_false(is_chezmoi)
		end)

		it("should try again if chezmoi is not installed", function()
			-- A failed probe is deliberately not pinned down: chezmoi can be
			-- installed in the middle of a session.
			local calls = 0
			io.popen = function(cmd)
				if cmd:match("^chezmoi") then
					calls = calls + 1
					return {
						read = function()
							return nil
						end,
						close = function() end,
					}
				end
				return {
					read = function()
						return "true"
					end,
					close = function() end,
				}
			end
			grn = require("insgitheader.helper.get-repo-name")
			grn.get_repo_name()
			vim._test.bufname = "/home/user/other/file.lua"
			grn.get_repo_name()
			assert.are.equal(2, calls)
		end)

		it("should answer the same buffer the second time without calling chezmoi", function()
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi source%-path ", SRC .. "/dot_bashrc.tmpl" },
				{ "show%-toplevel", SRC },
			})
			vim._test.bufname = "/home/user/.bashrc"
			grn = require("insgitheader.helper.get-repo-name")
			assert.are.equal(SRC, (grn.get_repo_name()))

			local seen = 0
			io.popen = function(cmd)
				seen = seen + 1
				return {
					read = function()
						return nil
					end,
					close = function() end,
				}
			end
			local repo, is_chezmoi = grn.get_repo_name()
			assert.are.equal(SRC, repo)
			assert.is_true(is_chezmoi)
			assert.are.equal(0, seen)
		end)
	end)
end)
