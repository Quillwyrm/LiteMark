-- -------------------------------------------------------------------------
-- DATA SCHEMA (SINGLE SOURCE OF TRUTH)
-- -------------------------------------------------------------------------

local TOKENS = {
  BLOCK = {
    HEADER    = 1,
    PARAGRAPH = 2,
    CODE      = 3,
    LIST      = 4,
    RULE      = 5
  },
  SPAN = {
    NONE   = 0,
    BOLD   = 1,
    ITALIC = 2,
    CODE   = 4 -- Bitmask ready
  }
}

-- -------------------------------------------------------------------------
-- INTERNAL HELPERS
-- -------------------------------------------------------------------------

local str_match = string.match
local str_sub   = string.sub
local str_find  = string.find

-- -------------------------------------------------------------------------
-- PHASE 1: BLOCK PARSER
-- Input: Raw String. Output: Flat Array of Block Tables.
-- -------------------------------------------------------------------------
local function parse_blocks(raw_text)
  local blocks = {}
  local block_count = 0
  
  -- Parser State
  local in_code_fence = false
  local current_fence_lang = nil
  local last_line_was_blank = false

  for line in raw_text:gmatch("([^\r\n]*)\r?\n?") do
    
    -- 1. CODE FENCE TOGGLE (```)
    if str_match(line, "^```") then
      if in_code_fence then
        in_code_fence = false
        current_fence_lang = nil
      else
        in_code_fence = true
        current_fence_lang = str_match(line, "^```%s*(%w+)")
        
        block_count = block_count + 1
        blocks[block_count] = { 
          type = TOKENS.BLOCK.CODE, 
          text = "", 
          arg  = current_fence_lang 
        }
      end

    -- 2. INSIDE CODE FENCE (Raw Slurp)
    elseif in_code_fence then
      local current_block = blocks[block_count]
      if current_block.text == "" then
        current_block.text = line
      else
        current_block.text = current_block.text .. "\n" .. line
      end

    -- 3. HEADER (# Title)
    elseif str_match(line, "^#+%s") then
      local hashes, content = str_match(line, "^(#+)%s+(.*)")
      block_count = block_count + 1
      blocks[block_count] = { 
        type = TOKENS.BLOCK.HEADER, 
        text = content, 
        arg  = #hashes -- level
      }
      last_line_was_blank = false

    -- 4. LIST ITEM (- Item)
    elseif str_match(line, "^%-%s") then
      local content = str_match(line, "^%-%s+(.*)")
      block_count = block_count + 1
      blocks[block_count] = { 
        type = TOKENS.BLOCK.LIST, 
        text = content 
      }
      last_line_was_blank = false

    -- 5. HORIZONTAL RULE (---)
    elseif str_match(line, "^%-%-%-+$") then
      block_count = block_count + 1
      blocks[block_count] = { type = TOKENS.BLOCK.RULE }
      last_line_was_blank = false

    -- 6. BLANK LINE
    elseif str_match(line, "^%s*$") then
      last_line_was_blank = true

    -- 7. PARAGRAPH (Text)
    else
      local last_block = blocks[block_count]
      
      -- Merge Logic
      if last_block and last_block.type == TOKENS.BLOCK.PARAGRAPH and not last_line_was_blank then
        last_block.text = last_block.text .. "\n" .. line
      else
        block_count = block_count + 1
        blocks[block_count] = { 
          type = TOKENS.BLOCK.PARAGRAPH, 
          text = line 
        }
      end
      last_line_was_blank = false
    end
  end

  return blocks
end

-- -------------------------------------------------------------------------
-- PHASE 2: SPAN TOKENIZER
-- Input: Raw String. Output: Flat Array of Token Tables.
-- -------------------------------------------------------------------------
local function parse_spans(text)
  local tokens = {}
  local token_count = 0
  
  -- A. MASKING PASS
  local mask_storage = {}
  local mask_id = 0
  local safe_text = text:gsub("(`+)(.-)%1", function(_, content)
    mask_id = mask_id + 1
    local key = "\0" .. mask_id .. "\0"
    mask_storage[key] = content
    return key
  end)

  -- B. SCAN PASS
  local pos = 1
  local len = #safe_text

  while pos <= len do
    local s_code = str_find(safe_text, "%z", pos)
    local s_bold = str_find(safe_text, "%*%*", pos)
    local s_ital = str_find(safe_text, "%*", pos)

    local first_idx = nil
    local mode = nil -- 1=Code, 2=Bold, 3=Italic

    -- Priority Check
    if s_code then 
      first_idx = s_code; mode = 1 
    end
    
    if s_bold and (not first_idx or s_bold < first_idx) then 
      first_idx = s_bold; mode = 2 
    end
    
    if s_ital and (not first_idx or s_ital < first_idx) then
       if not (s_bold and s_bold == s_ital) then
         first_idx = s_ital; mode = 3
       end
    end

    -- Flush Remaining
    if not first_idx then
      token_count = token_count + 1
      tokens[token_count] = { text = str_sub(safe_text, pos), style = TOKENS.SPAN.NONE }
      break
    end

    -- Flush Before
    if first_idx > pos then
      token_count = token_count + 1
      tokens[token_count] = { text = str_sub(safe_text, pos, first_idx - 1), style = TOKENS.SPAN.NONE }
    end

    -- Handle Content
    if mode == 1 then -- CODE
      local _, e_code = str_find(safe_text, "%z%d+%z", first_idx)
      local key = str_sub(safe_text, first_idx, e_code)
      token_count = token_count + 1
      tokens[token_count] = { text = mask_storage[key], style = TOKENS.SPAN.CODE }
      pos = e_code + 1

    elseif mode == 2 then -- BOLD
      local _, e_bold = str_find(safe_text, "%*%*.-%*%*", first_idx)
      if e_bold then
        token_count = token_count + 1
        tokens[token_count] = { text = str_sub(safe_text, first_idx + 2, e_bold - 2), style = TOKENS.SPAN.BOLD }
        pos = e_bold + 1
      else
        token_count = token_count + 1
        tokens[token_count] = { text = "**", style = TOKENS.SPAN.NONE }
        pos = first_idx + 2
      end

    elseif mode == 3 then -- ITALIC
      local _, e_ital = str_find(safe_text, "%*.-%*", first_idx)
      if e_ital then
        token_count = token_count + 1
        tokens[token_count] = { text = str_sub(safe_text, first_idx + 1, e_ital - 1), style = TOKENS.SPAN.ITALIC }
        pos = e_ital + 1
      else
        token_count = token_count + 1
        tokens[token_count] = { text = "*", style = TOKENS.SPAN.NONE }
        pos = first_idx + 1
      end
    end
  end

  return tokens
end

-- -------------------------------------------------------------------------
-- EXPORT
-- -------------------------------------------------------------------------

return {
  TOKENS       = TOKENS,
  parse_blocks = parse_blocks,
  parse_spans  = parse_spans
}
