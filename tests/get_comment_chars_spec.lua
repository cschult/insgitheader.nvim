describe("get-comment-chars", function()
	local gcc

	before_each(function()
		package.loaded["insgitheader.helper.get-comment-chars"] = nil
		gcc = require("insgitheader.helper.get-comment-chars")
	end)

	it("should parse a one-sided comment without a space: '--'", function()
		vim._test.commentstring = "--%s"
		local cleft, cright = gcc.get_comment_chars()
		assert.are.equal("--", cleft)
		assert.are.equal("", cright)
	end)

	it("should parse a one-sided comment with a space: '-- '", function()
		vim._test.commentstring = "-- %s"
		local cleft, cright = gcc.get_comment_chars()
		assert.are.equal("-- ", cleft)
		assert.are.equal("", cright)
	end)

	it("should parse a Python/shell comment: '# '", function()
		vim._test.commentstring = "# %s"
		local cleft, cright = gcc.get_comment_chars()
		assert.are.equal("# ", cleft)
		assert.are.equal("", cright)
	end)

	it("should parse a C block comment: '/* ... */'", function()
		vim._test.commentstring = "/* %s */"
		local cleft, cright = gcc.get_comment_chars()
		assert.are.equal("/* ", cleft)
		assert.are.equal(" */", cright)
	end)

	it("should parse an HTML comment: '<!-- ... -->'", function()
		vim._test.commentstring = "<!-- %s -->"
		local cleft, cright = gcc.get_comment_chars()
		assert.are.equal("<!-- ", cleft)
		assert.are.equal(" -->", cright)
	end)
end)
