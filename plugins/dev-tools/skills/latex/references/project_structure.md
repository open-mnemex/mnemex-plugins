# LaTeX Project Structure & Initialization

## Directory Layout

```
Project_Root/
├── main.tex              # Entry point (skeleton only)
├── references.bib        # Bibliography database
├── sections/             # Chapter/section content
│   ├── 01_xxx.tex
│   ├── 02_xxx.tex
│   └── ...
├── figures/              # All image assets
├── appendix/             # (Optional) Appendix content
│   ├── A_xxx.tex
│   └── B_xxx.tex
├── styles/               # Preamble & custom packages
│   └── preamble.tex
└── output/               # (Optional) Build artifacts
```

### Section naming by document type

**Research paper** — use standard paper sections:

```
sections/
├── 00_abstract.tex
├── 01_introduction.tex
├── 02_methodology.tex
├── 03_experiments.tex
└── 04_conclusion.tex
```

**Homework / report / other** — name by topic, not paper structure:

```
sections/
├── 01_forward_kinematics.tex
├── 02_inverse_kinematics.tex
├── 03_jacobian.tex
└── 04_workspace_analysis.tex
```

Rule: always use numeric prefixes (`01_`, `02_`, ...) so files
sort by logical order.

## main.tex — Skeleton Only

`main.tex` assembles parts; it must not contain actual content.

```latex
% !TEX program = xelatex
\documentclass[12pt, a4paper]{article}

\input{styles/preamble}

\title{Your Title Here}
\author{Author Name}
\date{\today}

\begin{document}
\maketitle
% \input{sections/00_abstract}   % paper only
\tableofcontents
\newpage

\input{sections/01_xxx}
\input{sections/02_xxx}

% \appendix                       % uncomment if needed
% \input{appendix/A_xxx}
% \input{appendix/B_xxx}

% \bibliographystyle{plain}      % uncomment if needed
% \bibliography{references}
\end{document}
```

## styles/preamble.tex

Move all `\usepackage` out of `main.tex` into preamble:

```latex
% styles/preamble.tex
\usepackage[margin=1in]{geometry}
\usepackage{amsmath,amssymb}
\usepackage{booktabs}
\usepackage{float}
\usepackage{graphicx}
\usepackage{listings}
\usepackage{xcolor}
\usepackage{fancyhdr}
\usepackage{siunitx}
\usepackage{hyperref}          % load near end

\graphicspath{{figures/}}
```

## `\input` vs `\include`

| Command          | Behavior                         | Use Case                |
|------------------|----------------------------------|-------------------------|
| `\input{file}`   | Direct insertion, no page break  | Sections, short content |
| `\include{file}` | Forces `\clearpage` before/after | Main chapters only      |

Use `\includeonly{sections/02_methodology}` during drafting to
compile only the current chapter — speeds up compilation.

## Image Management

- Use `\graphicspath{{figures/}}` so `\includegraphics` needs
  only filenames, not paths.
- For many images, use subfolders:
  `\graphicspath{{figures/ch1/}{figures/ch2/}}`
- Always use relative paths.

## .gitignore for LaTeX

```gitignore
*.aux
*.log
*.out
*.toc
*.lof
*.lot
*.fls
*.fdb_latexmk
*.synctex.gz
*.bbl
*.blg
```

## Section File Naming

- Always use numeric prefixes (`01_`, `02_`, ...).
- Paper: name by paper structure (`01_introduction`).
- Homework/report: name by topic (`01_forward_kinematics`).
