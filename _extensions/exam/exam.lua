-- Quarto/Pandoc filter for a paper exam.
--
-- MCQ authoring convention:
--   ::: {.mcq}
--   ### Question 1
--   Question text and options...
--   ::: {.answer}
--   B
--   :::
--   :::
--
-- Short-answer authoring convention with automatically labelled subparts:
--   ::: {.short-answer}
--   ### Question 21
--   Optional shared stem.
--
--   ::: {.part height="5cm"}
--   First sub-question.
--   ::: {.answer}
--   Expected solution.
--   :::
--   :::
--   :::
--
-- The `solutions` metadata flag controls whether answer content is printed.

local show_solutions = false
local show_student_number_header = true
local mcq_answer_text_latex = "Write your CAPITAL-letter answer in this box."
local mcq_count = 0

local function has_class(div, class_name)
  for _, class in ipairs(div.classes) do
    if class == class_name then
      return true
    end
  end
  return false
end

local function latex_from_blocks(blocks)
  if not blocks or #blocks == 0 then
    return ""
  end
  return pandoc.write(pandoc.Pandoc(blocks), "latex")
end

local function metadata_boolean(value, default_value)
  if value == nil then
    return default_value
  end
  if type(value) == "boolean" then
    return value
  end
  local text = pandoc.utils.stringify(value):lower()
  if text == "true" or text == "yes" or text == "1" or text == "on" then
    return true
  end
  if text == "false" or text == "no" or text == "0" or text == "off" then
    return false
  end
  return default_value
end

local function metadata_text_to_latex(value, default_text)
  local text = default_text
  if value ~= nil then
    text = pandoc.utils.stringify(value)
  end
  local doc = pandoc.Pandoc({pandoc.Para({pandoc.Str(text)})})
  local latex = pandoc.write(doc, "latex")
  latex = latex:gsub("^%s+", ""):gsub("%s+$", "")
  return latex
end

local function split_answer(blocks)
  local body = pandoc.Blocks({})
  local answer = pandoc.Blocks({})

  for _, block in ipairs(blocks) do
    if block.t == "Div" and has_class(block, "answer") then
      for _, answer_block in ipairs(block.content) do
        answer:insert(answer_block)
      end
    else
      body:insert(block)
    end
  end

  return body, answer
end

local function alpha_label(n)
  -- Supports more than 26 parts if ever needed: a ... z, aa, ab, ...
  local label = ""
  while n > 0 do
    n = n - 1
    label = string.char(97 + (n % 26)) .. label
    n = math.floor(n / 26)
  end
  return label
end

local function append_blocks(target, source)
  for _, block in ipairs(source) do
    target:insert(block)
  end
end

local function render_short_answer(div)
  local out = pandoc.Blocks({})
  local part_number = 0

  for _, block in ipairs(div.content) do
    if block.t == "Div" and has_class(block, "part") then
      part_number = part_number + 1
      local body, answer = split_answer(block.content)
      local height = block.attributes["height"] or "6cm"
      local env = show_solutions and "examsolutionbox" or "examanswerbox"
      local label = alpha_label(part_number)

      out:insert(pandoc.RawBlock("latex", "\\Needspace{\\dimexpr " .. height .. "+1.6cm\\relax}"))
      out:insert(pandoc.RawBlock("latex", "\\noindent\\textbf{(" .. label .. ")}\\hspace{0.5em}"))
      append_blocks(out, body)

      out:insert(pandoc.RawBlock("latex", "\\begin{" .. env .. "}{" .. height .. "}"))
      if show_solutions then
        local answer_tex = latex_from_blocks(answer)
        if answer_tex ~= "" then
          out:insert(pandoc.RawBlock("latex", answer_tex))
        end
      end
      out:insert(pandoc.RawBlock("latex", "\\end{" .. env .. "}"))
      out:insert(pandoc.RawBlock("latex", "\\vspace{0.35cm}"))
    else
      -- Heading and any shared question stem pass through unchanged.
      out:insert(block)
    end
  end

  -- Backward-compatible fallback: a short-answer block with no `.part`
  -- containers still gets one answer box using the old syntax.
  if part_number == 0 then
    local body, answer = split_answer(div.content)
    local height = div.attributes["height"] or "8cm"
    local env = show_solutions and "examsolutionbox" or "examanswerbox"
    out = pandoc.Blocks({})
    append_blocks(out, body)
    out:insert(pandoc.RawBlock("latex", "\\begin{" .. env .. "}{" .. height .. "}"))
    if show_solutions then
      local answer_tex = latex_from_blocks(answer)
      if answer_tex ~= "" then
        out:insert(pandoc.RawBlock("latex", answer_tex))
      end
    end
    out:insert(pandoc.RawBlock("latex", "\\end{" .. env .. "}"))
    out:insert(pandoc.RawBlock("latex", "\\vspace{0.35cm}"))
  end

  return out
end

local function transform_div(div)
  if has_class(div, "mcq") then
    mcq_count = mcq_count + 1
    local body, answer = split_answer(div.content)
    local answer_tex = ""

    if show_solutions then
      answer_tex = latex_from_blocks(answer)
      answer_tex = answer_tex:gsub("%s+$", "")
    end

    body:insert(pandoc.RawBlock("latex", "\\mcqanswer{" .. answer_tex .. "}{" .. mcq_answer_text_latex .. "}"))

    -- Hard page break after every second MCQ. This guarantees that no page can
    -- contain more than two MCQs, even if questions are short.
    if mcq_count % 2 == 0 then
      body:insert(pandoc.RawBlock("latex", "\\newpage"))
    else
      body:insert(pandoc.RawBlock("latex", "\\Needspace{0.38\\textheight}"))
    end

    return body
  end

  if has_class(div, "short-answer") then
    return render_short_answer(div)
  end

  return nil
end

function Pandoc(doc)
  mcq_count = 0

  show_solutions = metadata_boolean(doc.meta.solutions, false)
  show_student_number_header = metadata_boolean(doc.meta["student-number-header"], true)
  mcq_answer_text_latex = metadata_text_to_latex(
    doc.meta["mcq-answer-text"],
    "Write your CAPITAL-letter answer in this box."
  )

  local transformed = doc:walk({ Div = transform_div })

  -- Configure the running header before the first page is shipped out.
  if show_student_number_header then
    transformed.blocks:insert(1, pandoc.RawBlock("latex", "\\examstudentnumberheaderon"))
  else
    transformed.blocks:insert(1, pandoc.RawBlock("latex", "\\examstudentnumberheaderoff"))
  end

  return transformed
end
