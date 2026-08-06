local M = {}

-- Zeilen, die zwingend am Dateianfang stehen müssen; der Header wird darunter
-- einsortiert. Der Scan ist hart auf zwei Zeilen begrenzt: die coding-
-- Deklaration ist laut PEP 263 ohnehin nur in Zeile 1 oder 2 gültig, und die
-- Grenze verhindert, dass ein zufällig passender Kommentar weiter unten den
-- Header nach hinten schiebt.
local PROLOG_PATTERNS = {
	"^#!",
	"^<%?xml",
	"^<%?php",
	"^#.*coding[:=]",
	"^@charset",
}

local MAX_PROLOG_LINES = 2

function M.is_prolog(line)
	for _, pattern in ipairs(PROLOG_PATTERNS) do
		if line:match(pattern) then
			return true
		end
	end
	return false
end

-- Anzahl der zusammenhängenden Prolog-Zeilen am Dateianfang.
function M.prolog_length(lines)
	local n = 0
	while n < MAX_PROLOG_LINES and lines[n + 1] and M.is_prolog(lines[n + 1]) do
		n = n + 1
	end
	return n
end

local function escape(s)
	return (s:gsub("(%W)", "%%%1"))
end

local function is_blank(line)
	return line:match("^%s*$") ~= nil
end

-- Sucht den zusammenhängenden Dreierblock file:/git:/author: direkt hinter dem
-- Prolog, führende Leerzeilen überspringend. Weiter unten wird nicht gesucht,
-- damit kein fremder Kommentarblock erwischt wird.
-- Rückgabe: erste und letzte Zeilennummer (1-basiert) oder nil.
function M.find_block(lines, cleft)
	local prefix = "^%s*" .. escape(cleft) .. "%s*"
	local i = M.prolog_length(lines) + 1
	while lines[i] and is_blank(lines[i]) do
		i = i + 1
	end
	if not lines[i] or not lines[i]:match(prefix .. "file:") then
		return nil
	end
	if not lines[i + 1] or not lines[i + 1]:match(prefix .. "git:") then
		return nil
	end
	if not lines[i + 2] or not lines[i + 2]:match(prefix .. "author:") then
		return nil
	end
	return i, i + 2
end

-- Steht hinter dem Block (Leerzeilen ignoriert) eine Prolog-Zeile? Dann wurde
-- der Header seinerzeit darüber eingefügt und der Shebang ist wirkungslos.
function M.prolog_below(lines, last)
	local i = last + 1
	while lines[i] and is_blank(lines[i]) do
		i = i + 1
	end
	return lines[i] ~= nil and M.is_prolog(lines[i])
end

-- Zerlegt eine bestehende author-Zeile.
-- Rückgabe: erstes Jahr, bisheriger Autor, bereits vorhandene Vorautoren-Kette.
function M.parse_author(line)
	local body = line:match("author:%s*(.*)$")
	if not body then
		return nil
	end
	local chain = body:match("%(orig%.%s*(.-)%)")
	if chain then
		body = (body:gsub("%s*%(orig%..-%)", ""))
	end
	-- Das Jahresfeld ist das letzte Token, das für sich genommen ein Jahr oder
	-- ein Jahresbereich ist. Nicht das erste Vierziffernpaar: E-Mail-Adressen
	-- wie 12900332+user@example.com fangen durchaus mit Ziffern an.
	local first_year, who
	for pos, token in body:gmatch("()(%S+)") do
		if token:match("^%d%d%d%d$") or token:match("^%d%d%d%d%-%d%d%d%d$") then
			first_year = token:sub(1, 4)
			who = (body:sub(1, pos - 1):gsub("%s+$", ""))
		end
	end
	if who == "" then
		who = nil
	end
	return first_year, who, chain
end

return M
