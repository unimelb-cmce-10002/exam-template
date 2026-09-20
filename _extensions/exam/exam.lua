-- Quarto/Pandoc filter for a paper exam.
--
-- Exam-level options live in exam.qmd YAML. Question-level marks live with
-- short-answer questions/parts. MCQs share one YAML mark value.

local show_solutions = false
local show_student_number_header = true
local show_instructions_page = true
local mcq_answer_text_latex = "Write your CAPITAL-letter answer in this box."
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

local function render_mcq(div)
  mcq_count = mcq_count + 1
  local body, answer = split_answer(div.content)
  local out = pandoc.Blocks({})
  local answer_tex = ""

  if show_solutions then
    answer_tex = latex_from_blocks(answer):gsub("%s+$", "")
  end

  for _, block in ipairs(body) do
    if block.t == "Header" then
      out:insert(question_heading_from_header(block, mcq_points))
    else
      out:insert(block)
    end
  end

  out:insert(pandoc.RawBlock("latex", "\\mcqanswer{" .. answer_tex .. "}{" .. mcq_answer_text_latex .. "}"))

  -- Start each new pair of MCQs on a fresh page. Putting the break before
  -- questions 3, 5, ... avoids creating a blank page after the final MCQ.
  if mcq_count > 1 and mcq_count % 2 == 1 then
    out:insert(1, pandoc.RawBlock("latex", "\\newpage"))
  elseif mcq_count % 2 == 1 then
    out:insert(pandoc.RawBlock("latex", "\\Needspace{0.38\\textheight}"))
  end
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
