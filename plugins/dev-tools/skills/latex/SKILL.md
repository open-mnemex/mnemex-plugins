---
name: latex
description: >-
  LaTeX document writing for academic writing.
  Enforces consistent equation layout, labelling, and
  typographic conventions. Triggers on any .tex editing,
  equation writing, LaTeX compilation, or LaTeX project
  initialization task.
---

# LaTeX Conventions for Academic Reports

## 1. Engine & Build (Professional Workflow)

- Always use `xelatex`, never `pdflatex`.
- Magic comment at top of file: `% !TEX program = xelatex`
- **Single Version**: Keep entry point as `main.tex` and produce `main.pdf`.
- **Multi-Version (Conferences)**: Use multiple entry points (e.g., `main_icra.tex`, `main_iros.tex`) sharing the same `sections/` folder.
- **Development**: Produce `main.pdf` (or `main_xxx.pdf`) for 100% compatibility with LaTeX Workshop preview and SyncTeX.
- **Production/Release**: Use a `Makefile` to handle renaming for submission.

## 2. Project Automation (Makefile)

Every project MUST have a `Makefile` with the following standard targets:
- `all`: (Default) Compiles the main target(s).
- `release`: Compiles and creates properly named copies for submission.
- `clean`: Runs `latexmk -c` and removes residual junk files.
- **Multi-Version Support**: Makefile should define dynamic targets for each version (e.g., `make icra`).

## 3. Visual Cleanliness (VS Code Stealth Mode)

Intermediate files MUST stay in the root for tool compatibility but SHOULD be visually hidden.
- Initialize projects with a `.vscode/settings.json` file using `files.exclude`.

## 4. Multi-Step Derivations (CRITICAL)

**One `align` environment for the entire derivation.**
Each algebraic step is a new `&=` line.

```latex
\begin{align}
%--- definition ---
\mathbf{J} &= \frac{\partial \mathbf{f}}{\partial \mathbf{q}} \notag \\[0.8em]
%--- expansion ---
           &= \dots \label{eq:final}
\end{align}
```

## 5. File Splitting (REQUIRED)

**Always split by `\section`** — one section per file in `sections/`.
This allows sharing content between different `main_*.tex` versions and is essential for AI-friendly editing.

## 6. Project Structure

See [references/project_structure.md](references/project_structure.md)
for standard and multi-version directory layouts, `Makefile` templates,
and conditional compilation patterns.
