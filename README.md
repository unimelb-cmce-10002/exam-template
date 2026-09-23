# Quarto exam template — DRAFT

> **Status:** this is a draft teaching-team template. It is usable, but the layout and authoring conventions may still change as we test it on real exams. Please avoid one-off LaTeX fixes inside individual questions; if something repeatedly needs changing, update the template centrally.

This repo builds two PDF versions of the same exam:

- a **student version**, with blank answer boxes; and
- a **solutions version**, with answers printed inside the same boxes.

The main idea is that exam writers should mostly edit ordinary `.qmd` files. The Lua filter and LaTeX preamble handle marks, pagination, headers, answer boxes, section labels, and solution rendering.

## Normal workflow

1. Edit exam-wide settings at the top of `exam.qmd`.
2. Edit the instructions in `instructions/instructions.qmd` if instructions are being used.
3. Edit individual MCQs in `mcq/`.
4. Edit individual short-answer questions in `shortans/`.
5. Make sure any new question file is included in `exam.qmd` in the desired order.
6. Build both student and solutions PDFs.
7. Visually inspect the PDFs before release.

Build from the repository root with:

```bash
make student
make solutions
```

or build both with:

```bash
make all
```

The outputs are written to:

```text
_output/student/exam.pdf
_output/solutions/exam.pdf
```

You can also use Quarto directly:

```bash
quarto render exam.qmd --profile student
quarto render exam.qmd --profile solutions
```

## Repository structure

```text
.
├── exam.qmd
├── instructions/
│   └── instructions.qmd
├── mcq/
│   ├── q01.qmd
│   ├── q02.qmd
│   └── ...
├── shortans/
│   ├── q21.qmd
│   ├── q22.qmd
│   └── ...
├── _extensions/
│   └── exam/
│       ├── exam.lua
│       └── exam-preamble.tex
├── _quarto.yml
├── _quarto-student.yml
├── _quarto-solutions.yml
└── Makefile
```

Teaching staff will normally only need to edit `exam.qmd`, `instructions/`, `mcq/`, and `shortans/`.

## Exam-wide options

The top of `exam.qmd` contains the settings that exam writers are most likely to change:

```yaml
---
title: ""
format: pdf
student-number-header: true
instructions-page: true
first-page-number: 1
mcq-points-per-question: 1
mcq-answer-text: "Write your CAPITAL-letter answer in this box."
mcq-option-spacing: "0.5em"
mcq-section-title: "SECTION 1"
short-answer-section-title: "SECTION 2"
mcq-extra-pages: 1
short-answer-extra-pages: 1
---
```

### `student-number-header`

Use:

```yaml
student-number-header: true
```

to show the student-number field at the top of every page. Use `false` to remove it. There is deliberately no horizontal rule under the running header.

### `instructions-page`

Use:

```yaml
instructions-page: true
```

to include `instructions/instructions.qmd` as the first page. Use `false` to omit it completely.

### `first-page-number`

This controls the number printed on the first page of this PDF. For example:

```yaml
first-page-number: 3
```

makes the first page display `Page 3 of X`. The final page number `X` is adjusted consistently, so this works when the exam PDF follows other material that already occupies pages 1–2.

### MCQ marks

All MCQs currently share one mark value:

```yaml
mcq-points-per-question: 1
```

This is automatically included in every MCQ heading, for example:

```text
Question 1 (1 point)
```

The complete heading, including the mark value, is underlined.

### Section titles

Defaults are:

```yaml
mcq-section-title: "SECTION 1"
short-answer-section-title: "SECTION 2"
```

Both are printed in bold. Change the text here if a particular exam needs different section labels.

### Additional answer pages

Set the number of additional boxed writing pages after each section with:

```yaml
mcq-extra-pages: 1
short-answer-extra-pages: 1
```

Use `0` if no extra pages are required for a section. Every extra page begins with:

> **This is an extra page that can be used for answering questions**

followed by a large bordered writing area. The final exam page ends with centered bold `END OF EXAM`.

## Writing an MCQ

Each MCQ lives in its own file under `mcq/`:

```markdown
::: {.mcq}
### Question 1

Which option is correct?

A. First option  
B. Second option  
C. Third option  
D. Fourth option

::: {.answer}
B
:::
:::
```

Do **not** type the marks into the heading. The template reads `mcq-points-per-question` from the exam YAML and produces an underlined heading such as `Question 1 (1 point)`. A full line of whitespace is inserted automatically between the heading and the start of the question stem.

The sentence `Select the best answer from the following options` is also inserted automatically between the question stem and the options, with a full line of whitespace above and below it. Do **not** type this sentence into individual MCQ files.

For ordinary text options, keep using the compact syntax above. If an option needs block content such as code, put the option label on its own line and then write the block beneath it. For example:

````markdown
A.

```r
x <- 1:5
```

B.

```r
x <- c(1, 5)
```

C.

```r
x <- seq(1, 5, by = 5)
```

D.

```r
x <- "1:5"
```
````

The template recognises the standalone `A.`–`D.` labels automatically. The same approach can be used for multi-line equations, lists, tables, or other block content.

The student PDF places a large rectangular response box to the right of the default instruction:

> **Write your CAPITAL-letter answer in this box.**

The wording can be changed globally with `mcq-answer-text` in `exam.qmd`.

In the solutions PDF, the answer inside `.answer` is printed inside the same rectangle.

The template keeps every MCQ together and allows **at most two MCQs on a physical page**. Before placing a question, the PDF template measures its rendered height. If the complete question will not fit in the space remaining, it moves to the next page. The count then resets on that physical page, so the layout can recover naturally after a long question. For example, a long Question 1 may occupy a page by itself, while Questions 2 and 3 can share the following page if they fit.

An individual MCQ should still be short enough to fit on one full page. If a single question genuinely needs more than a page, it should be redesigned or handled as a special case rather than relying on the automatic MCQ layout.

## Adding or reordering MCQs

Create a new file, for example:

```text
mcq/q21.qmd
```

Then add it to the MCQ part of `exam.qmd`:

```markdown
{{< include mcq/q21.qmd >}}
```

Question order is determined by the include order in `exam.qmd`, not by filenames alone.

## Writing a short-answer question

Short-answer questions also live one per file. The total marks for the question are stored on the outer `.short-answer` block:

```markdown
::: {.short-answer points="10"}
### Question 21

A shared stem can go here.

::: {.part height="5cm" points="4"}
First subpart prompt.

::: {.answer}
Solution to the first subpart.
:::
:::

::: {.part height="6cm" points="6"}
Second subpart prompt.

::: {.answer}
Solution to the second subpart.
:::
:::
:::
```

The template renders the heading as an underlined:

```text
Question 21 (10 points)
```

Subparts are labelled automatically and reset to `(a)` for every new short-answer question. The example above becomes:

```text
(a) [4 points] First subpart prompt.
(b) [6 points] Second subpart prompt.
```

The `[Z points]` text is bold. Exam writers therefore only supply `points="..."`; they should **not** type `(a)`, `(b)`, or `[Z points]` themselves.

### Answer-box height

Each subpart controls its own writing-space height:

```markdown
::: {.part height="8cm" points="6"}
```

Use more height for questions that require more working. In the student version the box is blank; in the solutions version the solution appears inside a box with the same dimensions.

## Instructions page

The instructions live in:

```text
instructions/instructions.qmd
```

This keeps the first-page material separate from the question assembly file. If `instructions-page: false`, the file can remain in the repo and is simply omitted from the PDF.

## Section endings and final page

The assembly markers in `exam.qmd` automatically produce:

```text
END OF SECTION
```

centered and bold at the end of both Section 1 and Section 2.

Do not manually type these markers into question files. The additional-answer pages and final `END OF EXAM` are also generated centrally.

## Student and solutions versions

The same question files are used for both versions. Keep correct answers inside `.answer` blocks:

```markdown
::: {.answer}
Expected solution here.
:::
```

The student profile hides this content and leaves blank boxes. The solutions profile prints it inside those boxes.

## Files teaching staff normally should not edit

These files contain the template machinery:

```text
_extensions/exam/exam.lua
_extensions/exam/exam-preamble.tex
_quarto.yml
_quarto-student.yml
_quarto-solutions.yml
```

Change them only when changing the template itself. If one question has a layout problem, first ask whether the underlying rule should be improved for all questions rather than inserting custom LaTeX into that question.

## Pre-release checks

Before an exam is released, check both PDFs and confirm that:

- the instructions page is present or absent as intended;
- page numbering starts at the intended number and the final `of X` value is correct;
- the student-number header is present or absent as intended;
- every MCQ heading has the correct marks;
- there are no more than two MCQs on a page;
- MCQ answers in the solutions PDF match the intended options;
- every short-answer total and subpart mark is correct;
- short-answer boxes provide enough writing space;
- every section ends with `END OF SECTION`;
- the requested number of extra writing pages appears after each section; and
- the final page ends with `END OF EXAM`.

## Current draft conventions

For now, the template assumes:

- A4 paper;
- a PDF output;
- one common mark value for all MCQs;
- one student-number field in the running header;
- at most two MCQs per page;
- short-answer totals supplied on each question file;
- short-answer subpart marks and box heights supplied on each `.part`; and
- additional answer pages configured separately for the two sections.

These are conventions of the current **draft**, not permanent constraints. If the teaching team identifies a better workflow, change the template centrally and update this README.


### MCQ option spacing

MCQ options are automatically given extra vertical whitespace when written as `A.`, `B.`, `C.`, etc. No LaTeX is required in individual question files. Compact text options can remain on hard-broken lines, while standalone labels can introduce block content such as code. Control the amount globally with `mcq-option-spacing` in `exam.qmd`; use `"0em"` to disable it.
