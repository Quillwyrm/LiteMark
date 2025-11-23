local core    = require "core"
local common  = require "core.common"
local style   = require "core.style" -- Native Lite XL style (for colors)
local parser  = require "plugins.litenotes.mdparse"

-- -------------------------------------------------------------------------
-- DATA SCHEMA (CONSTANTS)
-- -------------------------------------------------------------------------

local CMD_TYPE = {
  TEXT = 1, -- {type=1, x, y, font, text, color}
  RECT = 2  -- {type=2, x, y, w, h, color}
}

-- Short aliases for parser constants
local B_TYPE = parser.TOKENS.BLOCK
local S_TYPE = parser.TOKENS.SPAN

-- -------------------------------------------------------------------------
-- ASSET GENERATION (FONT ATLAS)
-- -------------------------------------------------------------------------
-- Generates the matrix of fonts based on user config.
-- Structure:
--   Fonts.REGULAR / BOLD / ITALIC / CODE
--   Fonts.HEADER[level][style_id] -> FontObj
-- -------------------------------------------------------------------------
local Fonts = {}

local function load_assets(config)
  local base_size = config.fonts.size
  local fn_load   = renderer.font.load
  
  -- 1. LOAD BASE PALETTE
  Fonts.REGULAR = fn_load(config.fonts.regular, base_size)
  Fonts.BOLD    = fn_load(config.fonts.bold,    base_size)
  Fonts.ITALIC  = fn_load(config.fonts.italic,  base_size)
  Fonts.CODE    = fn_load(config.fonts.code,    base_size - 2) -- Tweak: -2px for code

  -- 2. GENERATE HEADER MATRIX (5 Levels x 3 Styles)
  -- H1=+10, H2=+6, H3=+4, H4=+2, H5=+0
  local h_offsets = { 10, 6, 4, 2, 0 }
  
  Fonts.HEADER = {}

  for level, offset in ipairs(h_offsets) do
    local size = base_size + offset
    Fonts.HEADER[level] = {}
    
    -- Map STYLE ID (0, 1, 2) to Font Object
    -- 0 = NONE (Regular)
    Fonts.HEADER[level][S_TYPE.NONE]   = fn_load(config.fonts.regular, size)
    -- 1 = BOLD
    Fonts.HEADER[level][S_TYPE.BOLD]   = fn_load(config.fonts.bold, size)
    -- 2 = ITALIC
    Fonts.HEADER[level][S_TYPE.ITALIC] = fn_load(config.fonts.italic, size)
    -- 4 = CODE (Fallback to Regular or load a big Mono? User said inline code doesn't matter for headers)
    Fonts.HEADER[level][S_TYPE.CODE]   = Fonts.HEADER[level][S_TYPE.NONE]
  end
end

-- -------------------------------------------------------------------------
-- LAYOUT HELPER: THE "PEN" (WRAPPING LOGIC)
-- -------------------------------------------------------------------------
local function layout_text_wrapped(ctx, text, base_font_set, is_code_block)
  local cmds = ctx.cmds
  
  -- If this is a header, base_font_set is a table [style] -> font
  -- If this is body, we need to manually map style -> font
  
  -- 1. PARSE SPANS (Just-In-Time)
  -- If it's a code block, we don't parse spans, we treat the whole line as raw text
  local tokens
  if is_code_block then
    tokens = { { text = text, style = S_TYPE.NONE } }
  else
    tokens = parser.parse_spans(text)
  end

  local space_w = 0 -- Calculated per-font if needed, simpler to append " " to words
  
  for _, token in ipairs(tokens) do
    -- A. RESOLVE FONT
    local active_font
    if is_code_block then
       active_font = Fonts.CODE
    elseif base_font_set == Fonts.HEADER then
       -- Header Matrix Lookup
       active_font = base_font_set[ctx.level][token.style] or base_font_set[ctx.level][S_TYPE.NONE]
    else
       -- Body Lookup
       if token.style == S_TYPE.BOLD then active_font = Fonts.BOLD
       elseif token.style == S_TYPE.ITALIC then active_font = Fonts.ITALIC
       elseif token.style == S_TYPE.CODE then active_font = Fonts.CODE
       else active_font = Fonts.REGULAR end
    end

    -- B. RESOLVE COLOR
    local color = style.text
    if token.style == S_TYPE.CODE and not is_code_block then
       color = style.accent -- Inline code highlight
    end

    -- C. WORD WRAP LOOP
    -- Split by spaces (naive but fast). 
    for word in token.text:gmatch("%S+") do
      local full_word = word .. " "
      local w = active_font:get_width(full_word)

      -- Wrap Check
      if ctx.x + w > ctx.max_w then
        ctx.x = ctx.indent
        ctx.y = ctx.y + active_font:get_height()
      end

      -- Record Command
      local idx = #cmds + 1
      cmds[idx] = { 
        type = CMD_TYPE.TEXT, 
        x = ctx.x, 
        y = ctx.y, 
        text = full_word, 
        font = active_font, 
        color = color 
      }

      -- Advance
      ctx.x = ctx.x + w
      if ctx.x > ctx.max_seen_w then ctx.max_seen_w = ctx.x end
    end
  end
  
  -- Advance Y for the next line (unless we are mid-span? No, Block parser sends full lines)
  -- Actually, we only advance Y if we explicitly wrapped. 
  -- But since the outer loop is Block-based, we usually end the block here.
  -- We return the line height of the *last used font* to prepare for next block.
  return (is_code_block and Fonts.CODE:get_height()) or Fonts.REGULAR:get_height()
end

-- -------------------------------------------------------------------------
-- COMPUTE PIPELINE
-- -------------------------------------------------------------------------
local function compute(blocks, max_width)
  local cmds = {}
  local ctx = {
    cmds = cmds,
    x = 0,
    y = 0,
    max_w = max_width - 20, -- Padding right
    max_seen_w = 0,
    indent = 0,
    level = 0
  }

  for _, block in ipairs(blocks) do
    
    -- 1. HEADER
    if block.type == B_TYPE.HEADER then
      ctx.y = ctx.y + 16 -- Margin Top
      ctx.x = 0
      ctx.indent = 0
      ctx.level = math.min(block.arg, 5) -- Clamp H6 -> H5 logic
      
      -- We pass the WHOLE header matrix as the "Base Font Set"
      local lh = layout_text_wrapped(ctx, block.text, Fonts.HEADER, false)
      ctx.y = ctx.y + lh + 4 -- Margin Bottom

    -- 2. PARAGRAPH
    elseif block.type == B_TYPE.PARAGRAPH then
      ctx.x = 0
      ctx.indent = 0
      local lh = layout_text_wrapped(ctx, block.text, nil, false)
      ctx.y = ctx.y + lh + 8 -- Paragraph Gap

    -- 3. LIST
    elseif block.type == B_TYPE.LIST then
      ctx.x = 20 -- Indent text
      ctx.indent = 20 -- Wrap indent matches
      
      -- Draw Bullet
      local bullet_y = ctx.y
      cmds[#cmds+1] = { 
        type = CMD_TYPE.TEXT, x = 5, y = bullet_y, 
        text = "•", font = Fonts.REGULAR, color = style.text 
      }
      
      local lh = layout_text_wrapped(ctx, block.text, nil, false)
      ctx.y = ctx.y + lh + 4

    -- 4. CODE BLOCK
    elseif block.type == B_TYPE.CODE then
      ctx.x = 0
      ctx.indent = 0
      local lh = Fonts.CODE:get_height()
      
      -- Background Rect Calculation is tricky because we iterate lines.
      -- Simpler: Draw Rect per line or measure first?
      -- DoD Approach: Just draw full width rects per line.
      
      -- Draw Lines
      -- Parser stores lines in block.text separated by \n? 
      -- Our parser stored them concatenated with \n. Correct.
      for line in block.text:gmatch("([^\n]*)\n?") do
         if line == "" and block.text:sub(-1) ~= "\n" then break end
         
         -- Draw Line BG
         cmds[#cmds+1] = { 
           type = CMD_TYPE.RECT, x = 0, y = ctx.y, w = max_width, h = lh, 
           color = style.line_highlight 
         }
         
         -- Draw Line Text
         layout_text_wrapped(ctx, line, nil, true) -- is_code=true
         
         ctx.x = 0
         ctx.y = ctx.y + lh
      end
      ctx.y = ctx.y + 8

    -- 5. RULE
    elseif block.type == B_TYPE.RULE then
      ctx.y = ctx.y + 8
      cmds[#cmds+1] = { 
        type = CMD_TYPE.RECT, x = 10, y = ctx.y, w = max_width - 20, h = 2, 
        color = style.dim 
      }
      ctx.y = ctx.y + 16
    end
  end

  return { 
    list = cmds, 
    height = ctx.y + 100, -- Scroll buffer
    width = ctx.max_seen_w 
  }
end

-- -------------------------------------------------------------------------
-- EXPORT
-- -------------------------------------------------------------------------
return {
  CMD_TYPE    = CMD_TYPE,
  load_assets = load_assets,
  compute     = compute
}
