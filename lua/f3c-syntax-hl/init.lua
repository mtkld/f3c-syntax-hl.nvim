local M = {}

-- Default configuration options
local default_opts = {}

local opts = {}

-- Merge user config with defaults
function M.setup(user_opts)
	-----------------------------------------------------------------------
	--  Regex‑based highlighter for *.f3c
	-----------------------------------------------------------------------
	-- ─┤ file: after/ftplugin/f3c.lua ├─────────────────────────────────────────────
	vim.filetype.add({ extension = { f3c = "f3c" } })

	local ns = vim.api.nvim_create_namespace("f3c_highlight")

	-- ── test colours (all deliberately garish) ───────────────────────────────────

	vim.api.nvim_set_hl(0, "F3CKey", { fg = "#ffb000" }) -- bright goldenrod (strong, sunlit key tone)
	vim.api.nvim_set_hl(0, "F3CBlock", { fg = "#586e75" }) -- slate grey-blue

	vim.api.nvim_set_hl(0, "F3CSpec", { fg = "#b58900" }) -- mustard gold
	vim.api.nvim_set_hl(0, "F3CString", { fg = "#859900" }) -- olive green
	vim.api.nvim_set_hl(0, "F3CNumber", { fg = "#d33682" }) -- faded rose
	vim.api.nvim_set_hl(0, "F3CBoolTrue", { fg = "#2aa198" }) -- teal
	vim.api.nvim_set_hl(0, "F3CBoolFalse", { fg = "#dc322f" }) -- clay red
	vim.api.nvim_set_hl(0, "F3CNull", { fg = "#839496" }) -- steel grey

	vim.api.nvim_set_hl(0, "F3CPunct", { fg = "#ffffff" }) -- pale dust
	vim.api.nvim_set_hl(0, "F3COther", { fg = "#657b83" }) -- stone blue-grey

	--replaced by other vim.api.nvim_set_hl(0, "F3CValue", { fg = "#ffffff" }) -- white
	-- ── helpers ──────────────────────────────────────────────────────────────────
	local function trim(s)
		return (s:gsub("^%s+", ""):gsub("%s+$", ""))
	end
	local function chop(val) -- strip comment / , / ; then trim
		return trim(val:gsub("[,;#].*$", ""))
	end

	-- helper that both trims *and* removes trailing “#…”, “;…”, or “, …”
	local function clean(val)
		-- 1. strip inline comment / delimiter
		val = val:gsub("[,;#].*$", "")
		-- 2. trim leading / trailing whitespace
		return (val:gsub("^%s+", ""):gsub("%s+$", ""))
	end

	local function classify_value(raw)
		local bare = clean(raw)
		local lower = bare:lower()

		if bare:match('^".-"$') then
			return "F3CString" --   "hello"
		elseif bare:match("^%-?%d+%.?%d*$") then
			return "F3CNumber" --   42, -7, 3.14
		elseif lower == "true" then
			return "F3CBoolTrue"
		elseif lower == "false" then
			return "F3CBoolFalse"
		elseif lower == "null" or lower == "nil" then
			return "F3CNull"
		else
			return "F3COther" --   any other atom
		end
	end

	local function highlight_punct(bufnr, row, line)
		-- dot or dots on their own line
		if line:match("^%s*%.%.%s*$") then
			local col = line:find("%.%.")
			vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CPunct", row, col - 1, col + 1)
		elseif line:match("^%s*%.%s*$") then
			local col = line:find("%.")
			vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CPunct", row, col - 1, col)
		end

		-- two dots at end of line
		local dd_s, dd_e = line:find("%.%.$")
		if dd_s then
			vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CPunct", row, dd_s - 1, dd_e)
		end

		-- every colon “:”
		for col in line:gmatch("()[:]") do
			vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CPunct", row, col - 1, col)
		end
	end

	-- ── main walker ──────────────────────────────────────────────────────────────
	local function highlight_f3c(bufnr)
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

		for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
			local touched = false

			--------------------------------------------------------------------------
			-- 1) key : value
			--------------------------------------------------------------------------
			local key_s, key_e = line:find("^%s*[%w_.-]+%s*:")
			if key_s then
				touched = true
				local key_end = line:find(":") - 1
				vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CKey", i - 1, key_s - 1, key_end)

				local raw_val = trim(line:sub(key_end + 2)) -- after ": "
				if #raw_val > 0 then
					local hl = classify_value(raw_val)
					local vcol = line:find(raw_val, key_end + 2, true) - 1
					vim.api.nvim_buf_add_highlight(bufnr, ns, hl, i - 1, vcol, vcol + #raw_val)
				end

			--------------------------------------------------------------------------
			-- 2) key ::
			--------------------------------------------------------------------------
			elseif line:match("^%s*%w+::%s*$") then
				touched = true
				local s, e = line:find("^%s*%w+")
				vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CBlock", i - 1, s - 1, e)

			--------------------------------------------------------------------------
			-- 3) key :TERM:
			--------------------------------------------------------------------------
			elseif line:match("^%s*%w+:%w+:%s*$") then
				touched = true
				local s, e = line:find("^%s*%w+")
				vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CSpec", i - 1, s - 1, e)

			--------------------------------------------------------------------------
			-- 4) :TERM:   (implicit key)
			--------------------------------------------------------------------------
			elseif line:match("^%s*:%w+:%s*$") then
				touched = true
				vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CSpec", i - 1, 0, -1)

			--------------------------------------------------------------------------
			-- 5) *only* a value on the line  (new rule)
			--------------------------------------------------------------------------
			-- 5) *only* a value on the line  (new rule)
			else
				touched = false
			end

			-- punctuation (colons always, dots per rules)
			if line:find("[:%.]") then
				highlight_punct(bufnr, i - 1, line)
			end

			-- whole‑line fallback
			if not touched and trim(line) ~= "" then
				vim.api.nvim_buf_add_highlight(bufnr, ns, "F3COther", i - 1, 0, -1)
			end
		end
	end

	vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
		pattern = "*.f3c",
		callback = function(a)
			highlight_f3c(a.buf)
		end,
	})
	-- ─────────────────────────────────────────────────────────────────────────────
end

return M
