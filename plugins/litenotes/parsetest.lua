local parser = require("mdparse")

-- -------------------------------------------------------------------------
-- DEBUG HELPER (Recursive Dump)
-- -------------------------------------------------------------------------
local function dump(node, indent)
  indent = indent or ""
  if type(node) == "table" then
    local s = indent .. "{\n"
    for k, v in pairs(node) do
      local key = type(k) == "number" and ("["..k.."]") or k
      local val
      if type(v) == "table" then
        val = "\n" .. dump(v, indent .. "  ")
      elseif type(v) == "string" then
        val = '"' .. v:gsub("\n", "\\n") .. '"'
      else
        val = tostring(v)
      end
      s = s .. indent .. "  " .. key .. " = " .. val .. ",\n"
    end
    return s .. indent .. "}"
  else
    return tostring(node)
  end
end

-- -------------------------------------------------------------------------
-- TEST DATA (The Spec)
-- Constructed via table to avoid Chat UI formatting errors
-- -------------------------------------------------------------------------
local input = table.concat({
  "# System Check",
  "This is a paragraph",
  "that should merge lines.",
  "",
  "- List Item A",
  "- List Item B",
  "",
  "```lua",          -- Start Code Fence
  "local x = 10",
  "```",             -- End Code Fence
  "",
  "Final text with **bold** and `code` styles."
}, "\n")

-- -------------------------------------------------------------------------
-- RUN PIPELINE
-- -------------------------------------------------------------------------

print("================ BLOCK PASS ================")
local blocks = parser.parse_blocks(input)
print(dump(blocks))

print("\n================ SPAN PASS =================")
-- Find the last paragraph (the one with bold/code) to test tokenizer
local target_text = ""
for i = #blocks, 1, -1 do
  if blocks[i].type == parser.TOKENS.BLOCK.PARAGRAPH then
    target_text = blocks[i].text
    break
  end
end

print("INPUT: " .. target_text)
local tokens = parser.parse_spans(target_text)
print(dump(tokens))
