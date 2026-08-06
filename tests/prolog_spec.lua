describe("prolog", function()
	local fh

	before_each(function()
		package.loaded["insgitheader.helper.find-header"] = nil
		fh = require("insgitheader.helper.find-header")
	end)

	describe("is_prolog()", function()
		it("should detect a shebang", function()
			assert.is_true(fh.is_prolog("#!/usr/bin/env bash"))
		end)

		it("should detect an XML declaration", function()
			assert.is_true(fh.is_prolog('<?xml version="1.0"?>'))
		end)

		it("should detect a PHP open tag", function()
			assert.is_true(fh.is_prolog("<?php"))
		end)

		it("should detect an encoding declaration", function()
			assert.is_true(fh.is_prolog("# -*- coding: utf-8 -*-"))
		end)

		it("should detect an @charset rule", function()
			assert.is_true(fh.is_prolog('@charset "UTF-8";'))
		end)

		it("should not detect ordinary code as a prologue", function()
			assert.is_false(fh.is_prolog("local x = 1"))
			assert.is_false(fh.is_prolog("# ein normaler Kommentar"))
		end)
	end)

	describe("prolog_length()", function()
		it("should return 0 without a prologue", function()
			assert.are.equal(0, fh.prolog_length({ "local x = 1" }))
		end)

		it("should count a single shebang line", function()
			assert.are.equal(1, fh.prolog_length({ "#!/bin/sh", "echo hi" }))
		end)

		it("should count shebang plus encoding line", function()
			local lines = { "#!/usr/bin/env python3", "# -*- coding: utf-8 -*-", "import sys" }
			assert.are.equal(2, fh.prolog_length(lines))
		end)

		it("should stop after two lines at most", function()
			local lines = { "#!/bin/sh", "#!/bin/sh", "#!/bin/sh" }
			assert.are.equal(2, fh.prolog_length(lines))
		end)

		it("should count only consecutive lines from line 1", function()
			local lines = { "echo hi", "#!/bin/sh" }
			assert.are.equal(0, fh.prolog_length(lines))
		end)

		it("should cope with an empty buffer", function()
			assert.are.equal(0, fh.prolog_length({}))
		end)
	end)

	describe("placement by insert_headers()", function()
		local ins
		local original_popen
		local original_getenv

		before_each(function()
			package.loaded["insgitheader"] = nil
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			package.loaded["insgitheader.helper.get-file-name"] = nil
			package.loaded["insgitheader.helper.get-git-config-user"] = nil
			package.loaded["insgitheader.helper.get-repo-name"] = nil
			package.loaded["insgitheader.helper.get-chezmoi"] = nil

			original_popen = io.popen
			original_getenv = os.getenv

			vim._test.commentstring = "# %s"
			vim._test.bufname = "/project/bin/foo.sh"

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
			ins.setup({})
		end)

		after_each(function()
			io.popen = original_popen
			os.getenv = original_getenv
		end)

		it("should put the block below the shebang with a blank line", function()
			vim._test.reset({ "#!/bin/bash", "set -e" })
			ins.insert_headers()
			assert.are.equal("#!/bin/bash", vim._test.lines[1])
			assert.are.equal("", vim._test.lines[2])
			assert.truthy(vim._test.lines[3]:match("^# file:"))
			assert.truthy(vim._test.lines[4]:match("^# git:"))
			assert.truthy(vim._test.lines[5]:match("^# author:"))
			assert.are.equal("", vim._test.lines[6])
			assert.are.equal("set -e", vim._test.lines[7])
		end)

		it("should reuse an existing blank line after the shebang", function()
			vim._test.reset({ "#!/bin/bash", "", "set -e" })
			ins.insert_headers()
			assert.are.equal("#!/bin/bash", vim._test.lines[1])
			assert.are.equal("", vim._test.lines[2])
			assert.truthy(vim._test.lines[3]:match("^# file:"))
			assert.are.equal("", vim._test.lines[6])
			assert.are.equal("set -e", vim._test.lines[7])
			assert.are.equal(7, #vim._test.lines)
		end)

		it("should put the block below shebang and coding line", function()
			vim._test.reset({ "#!/usr/bin/env python3", "# -*- coding: utf-8 -*-", "import sys" })
			ins.insert_headers()
			assert.are.equal("# -*- coding: utf-8 -*-", vim._test.lines[2])
			assert.are.equal("", vim._test.lines[3])
			assert.truthy(vim._test.lines[4]:match("^# file:"))
			assert.are.equal("import sys", vim._test.lines[8])
		end)

		it("should put the cursor on the file: line below the shebang", function()
			vim._test.reset({ "#!/bin/bash", "set -e" })
			ins.insert_headers()
			assert.are.same({ 3, 0 }, vim._test.cursor)
		end)
	end)
end)
