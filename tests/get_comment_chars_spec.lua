describe("get-comment-chars", function()
	local gcc

	before_each(function()
		package.loaded["insgitheader.helper.get-comment-chars"] = nil
		gcc = require("insgitheader.helper.get-comment-chars")
	end)

	it("parst einseitigen Kommentar ohne Leerzeichen: '--'", function()
		vim._test.commentstring = "--%s"
		local cleft, cright = gcc.get_comment_chars()
		assert.are.equal("--", cleft)
		assert.are.equal("", cright)
	end)

	it("parst einseitigen Kommentar mit Leerzeichen: '-- '", function()
		vim._test.commentstring = "-- %s"
		local cleft, cright = gcc.get_comment_chars()
		assert.are.equal("-- ", cleft)
		assert.are.equal("", cright)
	end)

	it("parst Python/Shell-Kommentar: '# '", function()
		vim._test.commentstring = "# %s"
		local cleft, cright = gcc.get_comment_chars()
		assert.are.equal("# ", cleft)
		assert.are.equal("", cright)
	end)

	it("parst C-Blockkommentar: '/* ... */'", function()
		vim._test.commentstring = "/* %s */"
		local cleft, cright = gcc.get_comment_chars()
		assert.are.equal("/* ", cleft)
		assert.are.equal(" */", cright)
	end)

	it("parst HTML-Kommentar: '<!-- ... -->'", function()
		vim._test.commentstring = "<!-- %s -->"
		local cleft, cright = gcc.get_comment_chars()
		assert.are.equal("<!-- ", cleft)
		assert.are.equal(" -->", cright)
	end)
end)
