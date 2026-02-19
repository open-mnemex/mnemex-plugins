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

## 1. Engine & Build

- Always use `xelatex`, never `pdflatex`.
- Magic comment at top of file: `% !TEX program = xelatex`

## 2. Multi-Step Derivations (CRITICAL)

This is the single most important rule.

**One `align` environment for the entire derivation.**
Each algebraic step is a new `&=` line.
Never break a derivation into separate equation environments.

```latex
\begin{align}
%--- definition ---
\mathbf{J}
  &= \frac{\partial \mathbf{f}}{\partial \mathbf{q}}
     \notag \\[0.8em]
%--- chain rule expansion ---
  &= \begin{pmatrix}
       \dfrac{\partial f_1}{\partial q_1} & \cdots \\
       \vdots & \ddots
     \end{pmatrix}
     \notag \\[0.8em]
%--- substitution ---
  &= \begin{pmatrix}
       -L_1 s_1 & 0 \\
        L_1 c_1 & 0
     \end{pmatrix}
     \label{eq:jacobian_final}
\end{align}
```

Rules:
- Separate steps with `\notag \\[0.8em]`
- Add `%--- step name ---` comments between steps
- Only the **final** line gets `\label{}`; all others get `\notag`
- Chain-rule expansions go **inside** the same `align` as a new
  `&=` `\begin{pmatrix}` line — never a separate environment

## 3. Boxed Final Results

Wrap important results in a boxed equation:

```latex
\begin{equation}\boxed{\begin{aligned}
  x &= a + b \\
  y &= c + d
  \quad\text{for } t > 0
\end{aligned}}\end{equation}
```

- Conditions go as `\quad\text{...}` inside the box.

## 4. Tables

```latex
\begin{table}[H]
  \centering
  \caption{Description of the table.}
  \label{tab:descriptive_name}
  \begin{tabular}{lcc}
    \toprule
    Header & Col 1 & Col 2 \\
    \midrule
    Row 1  & val   & val   \\
    \bottomrule
  \end{tabular}
\end{table}
```

- Always use `booktabs` (`\toprule`, `\midrule`, `\bottomrule`).
- Always include `\caption` and `\label{tab:...}`.
- Use `[H]` placement from the `float` package.

## 5. Labels

| Prefix | Object   | Example                          |
|--------|----------|----------------------------------|
| `eq:`  | Equation | `\label{eq:fk_serial}`           |
| `tab:` | Table    | `\label{tab:dh_parameters}`      |
| `fig:` | Figure   | `\label{fig:workspace_plot}`     |
| `sec:` | Section  | `\label{sec:forward_kinematics}` |

- Use `snake_case` descriptive names.

## 6. Text Conventions

- Non-breaking space with `~`:
  `Link~1`, `Eq.~\eqref{eq:name}`, `Fig.~\ref{fig:name}`
- Units via siunitx: `\SI{1.5}{m}`, `\SI{90}{\degree}`
- One sentence per source line in `.tex` files.
- After abbreviations: `e.g.\ `, `i.e.\ ` (backslash-space).

## 7. Section Decoration

```latex
% ============================================================
\section{Forward Kinematics}
\label{sec:forward_kinematics}

% ------------------------------------------------------------
\subsection{Serial Manipulator}
```

- `%` + 60 `=` chars before `\section`
- `%` + 60 `-` chars before `\subsection`

## 8. Standard Preamble Packages

```latex
\usepackage[margin=1in]{geometry}
\usepackage{amsmath,amssymb}
\usepackage{booktabs}
\usepackage{float}
\usepackage{graphicx}
\usepackage{listings}
\usepackage{xcolor}
\usepackage{hyperref}
\usepackage{fancyhdr}
\usepackage{siunitx}
```

- Pre-define code listing styles (arduino, python) as needed.
- Load `hyperref` near the end to avoid option clashes.

## 9. Project Structure

See [reference/project_structure.md](reference/project_structure.md)
for directory layout, `main.tex` skeleton, preamble template,
`\input` vs `\include`, image management, `.gitignore`, and
section file naming conventions.
