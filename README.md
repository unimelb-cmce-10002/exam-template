# Draft Quarto exam template

> **Status: draft template.** This repository is a working template for paper-based exams rendered from Quarto to PDF. It is ready to test and adapt, but the formatting and workflow should still be treated as provisional until the teaching team has used it on a real exam and agreed on the final conventions.

The template is designed so that most teaching-team members only need to edit normal Markdown/Quarto files. The LaTeX and Lua files under `_extensions/` control layout and automation and should generally be left alone unless someone is deliberately changing the template itself.

## What this template does

The repository supports:

- one source for both **student** and **solutions** PDFs;
- one file per MCQ under `mcq/`;
- one file per short-answer question under `shortans/`;
- a dedicated **instructions page** at the start of the exam;
- an optional **student number** field in the running header on every page;
- at most **two MCQs per page**;
- a large, right-aligned MCQ answer rectangle;
- configurable MCQ answer-box instructions;
- short-answer questions with automatically labelled subparts `(a)`, `(b)`, `(c)`, ...;
- independently sized answer boxes for each short-answer subpart; and
- solutions inserted into the same boxes that are blank in the student version.

## Requirements

You need:

1. [Quarto](https://quarto.org/)
2. a LaTeX installation capable of producing PDFs

If LaTeX is not already installed, Quarto's TinyTeX installation is usually the simplest option:

```bash
quarto install tinytex
```

You can confirm that Quarto is available with:

```bash
quarto --version
```

## Typical teaching-team workflow

For most exam editing, the workflow is:

1. edit the exam-wide instructions and options in `exam.qmd`;
2. edit or replace the individual files in `mcq/` and `shortans/`;
3. make sure the questions are included in the intended order in `exam.qmd`;
4. render the **student PDF**;
5. render the **solutions PDF**;
6. visually check both PDFs before circulating or printing them.

From the repository root, render with:

```bash
make student
make solutions
```

or render both at once:

```bash
make all
```

The output files are written to:

```text
_output/student/exam.pdf
_output/solutions/exam.pdf
```

You can also call Quarto directly:

```bash
quarto render exam.qmd --profile student
quarto render exam.qmd --profile solutions
```

## Repository structure

```text
.
├── _quarto.yml
├── _quarto-student.yml
├── _quarto-solutions.yml
├── exam.qmd
├── Makefile
├── README.md
├── mcq/
│   ├── q01.qmd
│   ├── q02.qmd
│   ├── ...
│   └── q20.qmd
├── shortans/
│   ├── q21.qmd
│   ├── q22.qmd
│   ├── q23.qmd
│   └── q24.qmd
└── _extensions/
    └── exam/
        ├── exam.lua
        └── exam-preamble.tex
```

The important distinction is:

- `exam.qmd`, `mcq/`, and `shortans/` are the files the teaching team will normally edit;
- `_extensions/exam/` contains the machinery that makes the template behave as intended.

## Editing `exam.qmd`

`exam.qmd` is the main assembly file. It contains:

- the exam-level YAML options;
- the first-page instructions; and
- the ordered list of question files to include.

The top of the file contains settings such as:

```yaml
---
title: ""
format: pdf
student-number-header: true
mcq-answer-text: "Write your CAPITAL-letter answer in this box."
---
```

### Student-number header

By default, every page contains a writable student-number field in the running header.

Keep it with:

```yaml
student-number-header: true
```

Turn it off with:

```yaml
student-number-header: false
```

### MCQ answer-box instruction

The default instruction beside every MCQ response box is:

> Write your CAPITAL-letter answer in this box.

To change it for the whole exam, change only the YAML entry in `exam.qmd`:

```yaml
mcq-answer-text: "Write one letter in this box."
```

Do not edit every MCQ individually to change this text.

## Instructions page

The opening content in `exam.qmd` is reserved for exam-wide instructions.

Keep information here that applies to the whole exam, such as:

- permitted materials;
- total marks;
- time allowed;
- how MCQ answers should be recorded;
- expectations for showing working; and
- any other general administrative instructions.

A hard page break separates the instructions from the questions, so the first question begins on the next page.

## Writing an MCQ

Each MCQ lives in its own file. For example, `mcq/q01.qmd` might contain:

```markdown
::: {.mcq}
### Question 1

Question text goes here.

A. First option  
B. Second option  
C. Third option  
D. Fourth option

::: {.answer}
B
:::
:::
```

The content inside `.answer` is the correct answer.

In the **student version**, the answer is hidden and the student sees a blank rectangular response box.

In the **solutions version**, the same box contains the correct answer.

### MCQ conventions

For now, please keep to the following conventions:

- use capital letters for options: `A.`, `B.`, `C.`, etc.;
- put only the correct capital letter inside the `.answer` block;
- keep each MCQ in a separate file; and
- do not manually insert page breaks between MCQs.

The template automatically inserts a page break after every second MCQ, giving a maximum of two MCQs per page.

## Adding another MCQ

Suppose you want to add Question 21.

1. Create a new file:

```text
mcq/q21.qmd
```

2. Copy the structure of an existing MCQ and edit the content.

3. Add it to `exam.qmd` in the position where it should appear:

```markdown
{{< include mcq/q21.qmd >}}
```

The question number in the heading is currently written explicitly, so make sure it matches the intended order.

## Writing a short-answer question

Each short-answer question also lives in its own file. A question can have as many subparts as needed.

For example:

```markdown
::: {.short-answer}
### Question 21

A shared question stem can go here.

::: {.part height="5cm"}
First prompt.

::: {.answer}
Expected answer to the first prompt.
:::
:::

::: {.part height="7cm"}
Second prompt.

::: {.answer}
Expected answer to the second prompt.
:::
:::
:::
```

This renders the two subparts as `(a)` and `(b)` automatically.

Do **not** manually type `(a)`, `(b)`, and so on. The lettering resets to `(a)` for every new short-answer question.

## Controlling short-answer box size

Each `.part` has its own `height` setting:

```markdown
::: {.part height="5cm"}
```

Use a smaller height for brief responses and a larger height when students need more room.

For example:

```text
3cm   short response
5cm   moderate response
8cm   longer response
12cm  substantial response
```

These are only rough guides. Always render the PDF and inspect the actual layout.

If `height` is omitted, the template currently defaults to `6cm`.

## Solutions for short-answer questions

Put the expected solution inside the nested `.answer` block:

```markdown
::: {.answer}
The expected answer goes here.
:::
```

The student PDF hides this content and leaves the box blank. The solutions PDF places the answer inside the same box.

The solution can contain normal Markdown, including emphasis, lists, equations, and code where appropriate.

## Adding another short-answer question

To add another question:

1. create a new file in `shortans/`, for example:

```text
shortans/q25.qmd
```

2. copy the structure of an existing short-answer question;
3. add or remove `.part` blocks as required;
4. set a sensible `height` for each response box; and
5. add the file to `exam.qmd`:

```markdown
{{< include shortans/q25.qmd >}}
```

## Reordering or removing questions

The order of the include statements in `exam.qmd` determines the order of questions in the exam.

To reorder questions, move the relevant include lines.

To remove a question from the exam without deleting its source file, remove or comment out its include line.

Because the top-level question numbers are currently explicit, update the `### Question ...` heading inside each file if the order changes.

Automatic numbering of top-level questions may be added later, but it is deliberately not part of this draft yet.

## What teaching-team members should usually edit

Most contributors should only need to edit:

```text
exam.qmd
mcq/*.qmd
shortans/*.qmd
```

If you are only writing or revising exam questions, there should normally be no reason to edit the files under `_extensions/`.

## Extending the template itself

The template machinery lives here:

```text
_extensions/exam/exam.lua
_extensions/exam/exam-preamble.tex
```

Broadly:

- `exam.lua` controls conditional student/solutions rendering, MCQ pagination, metadata options, and automatic short-answer subpart labels;
- `exam-preamble.tex` controls PDF layout, margins, headers/footers, typography, and the visual styling of the response boxes.

Changes here affect the entire exam, so they should be tested against both student and solutions output.

If extending the template, a useful rule is to keep **content decisions** in the `.qmd` files and **formatting/automation decisions** in the extension files.

## Recommended checks before an exam is final

Before distributing a final exam, the teaching team should check both the student and solutions PDFs for:

- correct question order and numbering;
- correct MCQ answers in the solutions version;
- solutions matching the intended marking logic;
- no more than two MCQs on each MCQ page;
- enough writing space for every short-answer part;
- no answer box or question awkwardly split across pages;
- correct student-number-header behaviour;
- correct instructions on page 1;
- equations, tables, figures, and code rendering correctly; and
- page count and print layout looking sensible when viewed at actual size.

The PDF should always be inspected visually. A successful Quarto build does not guarantee that the physical exam layout is good.

## Troubleshooting

### `quarto` is not found

Check that Quarto is installed and available on your PATH:

```bash
quarto --version
```

### PDF rendering fails because LaTeX is missing

Install TinyTeX:

```bash
quarto install tinytex
```

### A question is missing from the PDF

Check that its file is included in `exam.qmd`.

### A solution appears in the student version

Check that the solution is inside a correctly nested:

```markdown
::: {.answer}
...
:::
```

block.

### Short-answer subparts are not labelled correctly

Check that each subpart uses:

```markdown
::: {.part height="..."}
...
:::
```

inside a surrounding `.short-answer` block.

### Layout looks wrong after changing the template machinery

Render both versions again:

```bash
make all
```

and compare the PDFs carefully. If the issue came from a change under `_extensions/`, revert that change before editing individual questions as a workaround.

## Draft-template notes

This repository is intentionally a **draft** rather than a locked production template. In particular, we may still want to refine:

- typography and spacing;
- exact answer-box dimensions;
- instructions-page styling;
- handling of unusually long MCQs;
- top-level question numbering;
- mark allocations and display conventions;
- figures/tables inside questions;
- page-break behaviour for long short-answer questions; and
- any University-specific front-page or examination requirements.

Please flag recurring problems rather than solving them by adding one-off LaTeX to individual question files. If a formatting issue occurs repeatedly, it is better to fix the template once for everyone.
