describe("prolog", function()
	local fh

	before_each(function()
		package.loaded["insgitheader.helper.find-header"] = nil
		fh = require("insgitheader.helper.find-header")
	end)

	describe("is_prolog()", function()
		it("erkennt einen Shebang", function()
			assert.is_true(fh.is_prolog("#!/usr/bin/env bash"))
		end)

		it("erkennt eine XML-Deklaration", function()
			assert.is_true(fh.is_prolog('<?xml version="1.0"?>'))
		end)

		it("erkennt ein PHP-Open-Tag", function()
			assert.is_true(fh.is_prolog("<?php"))
		end)

		it("erkennt eine Encoding-Deklaration", function()
			assert.is_true(fh.is_prolog("# -*- coding: utf-8 -*-"))
		end)

		it("erkennt eine @charset-Regel", function()
			assert.is_true(fh.is_prolog('@charset "UTF-8";'))
		end)

		it("erkennt gewöhnlichen Code nicht als Prolog", function()
			assert.is_false(fh.is_prolog("local x = 1"))
			assert.is_false(fh.is_prolog("# ein normaler Kommentar"))
		end)
	end)

	describe("prolog_length()", function()
		it("gibt 0 zurück ohne Prolog", function()
			assert.are.equal(0, fh.prolog_length({ "local x = 1" }))
		end)

		it("zählt eine einzelne Shebang-Zeile", function()
			assert.are.equal(1, fh.prolog_length({ "#!/bin/sh", "echo hi" }))
		end)

		it("zählt Shebang plus Encoding-Zeile", function()
			local lines = { "#!/usr/bin/env python3", "# -*- coding: utf-8 -*-", "import sys" }
			assert.are.equal(2, fh.prolog_length(lines))
		end)

		it("hört bei maximal zwei Zeilen auf", function()
			local lines = { "#!/bin/sh", "#!/bin/sh", "#!/bin/sh" }
			assert.are.equal(2, fh.prolog_length(lines))
		end)

		it("zählt nur zusammenhängende Zeilen ab Zeile 1", function()
			local lines = { "echo hi", "#!/bin/sh" }
			assert.are.equal(0, fh.prolog_length(lines))
		end)

		it("kommt mit einem leeren Puffer zurecht", function()
			assert.are.equal(0, fh.prolog_length({}))
		end)
	end)

	describe("Platzierung durch insert_headers()", function()
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

		it("setzt den Block mit Leerzeile unter den Shebang", function()
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

		it("verwendet eine vorhandene Leerzeile nach dem Shebang", function()
			vim._test.reset({ "#!/bin/bash", "", "set -e" })
			ins.insert_headers()
			assert.are.equal("#!/bin/bash", vim._test.lines[1])
			assert.are.equal("", vim._test.lines[2])
			assert.truthy(vim._test.lines[3]:match("^# file:"))
			assert.are.equal("", vim._test.lines[6])
			assert.are.equal("set -e", vim._test.lines[7])
			assert.are.equal(7, #vim._test.lines)
		end)

		it("setzt den Block unter Shebang und coding-Zeile", function()
			vim._test.reset({ "#!/usr/bin/env python3", "# -*- coding: utf-8 -*-", "import sys" })
			ins.insert_headers()
			assert.are.equal("# -*- coding: utf-8 -*-", vim._test.lines[2])
			assert.are.equal("", vim._test.lines[3])
			assert.truthy(vim._test.lines[4]:match("^# file:"))
			assert.are.equal("import sys", vim._test.lines[8])
		end)

		it("setzt den Cursor auf die file:-Zeile unter dem Shebang", function()
			vim._test.reset({ "#!/bin/bash", "set -e" })
			ins.insert_headers()
			assert.are.same({ 3, 0 }, vim._test.cursor)
		end)
	end)
end)
