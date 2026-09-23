-- Quarto/Pandoc filter for a paper exam.
--
-- Exam-level options live in exam.qmd YAML. Question-level marks live with
-- short-answer questions/parts. MCQs share one YAML mark value.

local show_solutions = false
local show_student_number_header = true
local show_instructions_page = true
local mcq_answer_text_latex = "Write your CAPITAL-letter answer in this box."
local mcq_option_spacing = "0.5em"
local mcq_section_title_latex = "SECTION 1"
local short_answer_section_title_latex = "SECTION 2"
local mcq_points = "1 point"
local first_page_number = 1
local mcq_extra_pages = 0
local short_answer_extra_pages = 0
local mcq_count = 0

local function has_class(div, class_name)
  for _, class in ipairs(div.classes) do
    if class == class_name then return true end
  end
  return false
end

local function latex_from_blocks(blocks)
  if not blocks or #blocks == 0 then return "" end
  return pandoc.write(pandoc.Pandoc(blocks), "latex")
end

local function metadata_boolean(value, default_value)
  if value == nil then return default_value end
  if type(value) == "boolean" then return value end
  local text = pandoc.utils.stringify(value):lower()
  if text == "true" or text == "yes" or text == "1" or text == "on" then return true end
  if text == "false" or text == "no" or text == "0" or text == "off" then return false end
  return default_value
end

local function metadata_number(value, default_value)
  if value == nil then return default_value end
  local n = tonumber(pandoc.utils.stringify(value))
  if n == nil then return default_value end
  return n
end

local function text_to_latex(text)
  local doc = pandoc.Pandoc({pandoc.Para({pandoc.Str(text)})})
  local latex = pandoc.write(doc, "latex")
  return latex:gsub("^%s+", ""):gsub("%s+$", "")
end

local function metadata_text_to_latex(value, default_text)
  local text = default_text
  if value ~= nil then text = pandoc.utils.stringify(value) end
  return text_to_latex(text)
end

local function points_label(raw)
  local text = tostring(raw or "")
  local n = tonumber(text)
  if n == 1 then return "1 point" end
  if n ~= nil then return text .. " points" end
  if text == "" then return "points not set" end
  return text
end

local function split_answer(blocks)
  local body = pandoc.Blocks({})
  local answer = pandoc.Blocks({})
  for _, block in ipairs(blocks) do
    if block.t == "Div" and has_class(block, "answer") then
      for _, answer_block in ipairs(block.content) do answer:insert(answer_block) end
    else
      body:insert(block)
    end
  end
  return body, answer
end

local function alpha_label(n)
  local label = ""
  while n > 0 do
    n = n - 1
    label = string.char(97 + (n % 26)) .. label
    n = math.floor(n / 26)
  end
  return label
end

local function append_blocks(target, source)
  for _, block in ipairs(source) do target:insert(block) end
end

local function question_heading_from_header(block, mark_text)
  local heading = pandoc.utils.stringify(block.content)
  return pandoc.RawBlock(
    "latex",
    "\\examquestionheading{" .. text_to_latex(heading) .. "}{" .. text_to_latex(mark_text) .. "}"
  )
end

local function render_short_answer(div)
  local out = pandoc.Blocks({})
  local part_number = 0
  local question_points = points_label(div.attributes["points"])

  for _, block in ipairs(div.content) do
    if block.t == "Header" then
      out:insert(question_heading_from_header(block, question_points))
    elseif block.t == "Div" and has_class(block, "part") then
      part_number = part_number + 1
      local body, answer = split_answer(block.content)
      local height = block.attributes["height"] or "6cm"
      local env = show_solutions and "examsolutionbox" or "examanswerbox"
      local label = alpha_label(part_number)
      local part_points = points_label(block.attributes["points"])

      out:insert(pandoc.RawBlock("latex", "\\Needspace{\\dimexpr " .. height .. "+1.8cm\\relax}"))
      out:insert(pandoc.RawBlock(
        "latex",
        "\\noindent(" .. label .. ")\\hspace{0.45em}\\textbf{[" .. text_to_latex(part_points) .. "]}\\hspace{0.5em}"
      ))
      append_blocks(out, body)
      out:insert(pandoc.RawBlock("latex", "\\begin{" .. env .. "}{" .. height .. "}"))
      if show_solutions then
        local answer_tex = latex_from_blocks(answer)
        if answer_tex ~= "" then out:insert(pandoc.RawBlock("latex", answer_tex)) end
      end
      out:insert(pandoc.RawBlock("latex", "\\end{" .. env .. "}"))
      out:insert(pandoc.RawBlock("latex", "\\vspace{0.35cm}"))
    else
      out:insert(block)
    end
  end

  return out
end


local function option_letter_from_inlines(inlines)
  if not inlines or #inlines == 0 then return nil end
  local first = inlines[1]
  if not first or first.t ~= "Str" then return nil end
  return first.text:match("^([A-Z])%.$")
end

local function expected_option_letter(n)
  if n < 1 or n > 26 then return nil end
  return string.char(64 + n)
end

local function split_hardbreak_option_paragraph(block)
  if block.t ~= "Para" or #block.content == 0 then return nil end

  local lines = {}
  local current = pandoc.Inlines({})
  for _, inline in ipairs(block.content) do
    if inline.t == "LineBreak" then
      lines[#lines + 1] = current
      current = pandoc.Inlines({})
    else
      current:insert(inline)
    end
  end
  lines[#lines + 1] = current

  if #lines < 2 then return nil end
  for i, line in ipairs(lines) do
    if option_letter_from_inlines(line) ~= expected_option_letter(i) then return nil end
  end

  local groups = {}
  for _, line in ipairs(lines) do
    groups[#groups + 1] = pandoc.Blocks({pandoc.Para(line)})
  end
  return groups
end

local function empty_alpha_list_marker_letter(block)
  if block.t ~= "OrderedList" then return nil end
  if tostring(block.style) ~= "UpperAlpha" or tostring(block.delimiter) ~= "Period" then return nil end
  if #block.content ~= 1 or #block.content[1] ~= 0 then return nil end
  local start = tonumber(block.start)
  return expected_option_letter(start)
end

local function option_marker_letter(block)
  if block.t == "Para" and #block.content > 0 then
    return option_letter_from_inlines(block.content)
  end
  return empty_alpha_list_marker_letter(block)
end

local function block_starts_option(block, expected_letter)
  return option_marker_letter(block) == expected_letter
end

local function normalized_option_marker_block(block, letter)
  -- Markdown interprets a standalone `A.` as an empty alphabetic ordered-list
  -- item. Convert that parser representation back into the simple label the
  -- exam author intended, while retaining normal `A. text` paragraphs as-is.
  if block.t == "OrderedList" then
    return pandoc.Para({pandoc.Str(letter .. ".")})
  end
  return block
end

-- Split MCQ content into stem blocks and option groups. This supports both:
--   A. inline option text  \\ hard line break
--   B. inline option text
-- and block-style options such as:
--   A.
--
--   ```r
--   some_code()
--   ```
-- The latter lets an option contain code, equations, lists, tables, etc.
local function split_mcq_stem_and_options(blocks)
  local stem = pandoc.Blocks({})
  local groups = nil
  local i = 1

  while i <= #blocks do
    local block = blocks[i]

    -- Existing compact syntax: all options in one hard-broken paragraph.
    local hardbreak_groups = split_hardbreak_option_paragraph(block)
    if hardbreak_groups then
      groups = hardbreak_groups
      for j = i + 1, #blocks do
        -- Anything after the compact option paragraph is retained as part of
        -- the final option. This is unusual, but avoids silently discarding it.
        groups[#groups]:insert(blocks[j])
      end
      return stem, groups
    end

    -- Block-style syntax begins with A. and then expects B., C., ...
    if block_starts_option(block, "A") then
      groups = {}
      local option_number = 1
      local current = pandoc.Blocks({})

      while i <= #blocks do
        block = blocks[i]
        local expected = expected_option_letter(option_number)
        if block_starts_option(block, expected) then
          if #current > 0 then groups[#groups + 1] = current end
          current = pandoc.Blocks({normalized_option_marker_block(block, expected)})
          option_number = option_number + 1
        else
          -- If a later paragraph begins with a different option label, the
          -- sequence is malformed; treat the whole thing as ordinary content.
          local actual = option_marker_letter(block)
          if actual ~= nil and actual ~= expected then
            return blocks, nil
          end
          current:insert(block)
        end
        i = i + 1
      end

      if #current > 0 then groups[#groups + 1] = current end
      if #groups >= 2 then return stem, groups end
      return blocks, nil
    end

    stem:insert(block)
    i = i + 1
  end

  return stem, nil
end

local function append_mcq_options(out, groups)
  for i, group in ipairs(groups) do
    if i > 1 and mcq_option_spacing ~= "0em" and mcq_option_spacing ~= "0" then
      out:insert(pandoc.RawBlock("latex", "\\vspace{" .. mcq_option_spacing .. "}"))
    end
    append_blocks(out, group)
  end
end

local function render_mcq(div)
  mcq_count = mcq_count + 1
  local body, answer = split_answer(div.content)
  local out = pandoc.Blocks({})
  local answer_tex = ""

  if show_solutions then
    answer_tex = latex_from_blocks(answer):gsub("%s+$", "")
  end

  -- TeX measures the complete MCQ before placing it. This keeps the question
  -- together, starts a new page when the remaining space is insufficient, and
  -- enforces a maximum of two MCQs on a physical page.
  out:insert(pandoc.RawBlock("latex", "\\begin{exammcqbox}"))

  local content = pandoc.Blocks({})
  for _, block in ipairs(body) do
    if block.t == "Header" then
      out:insert(question_heading_from_header(block, mcq_points))
    else
      content:insert(block)
    end
  end

  local stem, option_groups = split_mcq_stem_and_options(content)
  append_blocks(out, stem)
  if option_groups then
    out:insert(pandoc.RawBlock("latex", "\\exammcqinstruction"))
    append_mcq_options(out, option_groups)
  end

  out:insert(pandoc.RawBlock("latex", "\\mcqanswer{" .. answer_tex .. "}{" .. mcq_answer_text_latex .. "}"))
  out:insert(pandoc.RawBlock("latex", "\\end{exammcqbox}"))
  return out
end

local function extra_pages(n)
  local out = pandoc.Blocks({})
  for _ = 1, n do out:insert(pandoc.RawBlock("latex", "\\examextrapage")) end
  return out
end

local function transform_div(div)
  if has_class(div, "instructions-page") then
    if not show_instructions_page then return pandoc.Blocks({}) end
    local out = pandoc.Blocks({})
    append_blocks(out, div.content)
    out:insert(pandoc.RawBlock("latex", "\\clearpage"))
    return out
  end

  if has_class(div, "mcq") then return render_mcq(div) end
  if has_class(div, "short-answer") then return render_short_answer(div) end

  if has_class(div, "section-heading") then
    local section = div.attributes["section"] or ""
    local title = section == "mcq" and mcq_section_title_latex or short_answer_section_title_latex
    local prefix = section == "short-answer" and "\\clearpage" or ""
    return pandoc.Blocks({pandoc.RawBlock("latex", prefix .. "\\examsectiontitle{" .. title .. "}")})
  end

  if has_class(div, "section-end") then
    return pandoc.Blocks({pandoc.RawBlock("latex", "\\examendsection")})
  end

  if has_class(div, "extra-pages") then
    local section = div.attributes["section"] or ""
    return extra_pages(section == "mcq" and mcq_extra_pages or short_answer_extra_pages)
  end

  if has_class(div, "exam-end") then
    return pandoc.Blocks({pandoc.RawBlock("latex", "\\examendexam")})
  end

  return nil
end

function Pandoc(doc)
  mcq_count = 0
  show_solutions = metadata_boolean(doc.meta.solutions, false)
  show_student_number_header = metadata_boolean(doc.meta["student-number-header"], true)
  show_instructions_page = metadata_boolean(doc.meta["instructions-page"], true)
  first_page_number = math.floor(metadata_number(doc.meta["first-page-number"], 1))
  mcq_extra_pages = math.max(0, math.floor(metadata_number(doc.meta["mcq-extra-pages"], 0)))
  short_answer_extra_pages = math.max(0, math.floor(metadata_number(doc.meta["short-answer-extra-pages"], 0)))
  mcq_points = points_label(pandoc.utils.stringify(doc.meta["mcq-points-per-question"] or "1"))
  mcq_answer_text_latex = metadata_text_to_latex(doc.meta["mcq-answer-text"], "Write your CAPITAL-letter answer in this box.")
  mcq_option_spacing = pandoc.utils.stringify(doc.meta["mcq-option-spacing"] or "0.5em")
  mcq_section_title_latex = metadata_text_to_latex(doc.meta["mcq-section-title"], "SECTION 1")
  short_answer_section_title_latex = metadata_text_to_latex(doc.meta["short-answer-section-title"], "SECTION 2")

  local transformed = doc:walk({ Div = transform_div })
  transformed.blocks:insert(1, pandoc.RawBlock("latex", "\\setcounter{page}{" .. first_page_number .. "}"))
  if show_student_number_header then
    transformed.blocks:insert(1, pandoc.RawBlock("latex", "\\examstudentnumberheaderon"))
  else
    transformed.blocks:insert(1, pandoc.RawBlock("latex", "\\examstudentnumberheaderoff"))
  end
  return transformed
end
