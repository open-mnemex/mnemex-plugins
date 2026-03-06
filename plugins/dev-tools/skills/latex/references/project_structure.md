# LaTeX Project Structure & Initialization

## Standard Directory Layout

```
Project_Root/
├── main.tex              # Entry point (skeleton only)
├── Makefile              # Development & Release automation
├── latexmkrc             # Engine settings (xelatex)
├── references.bib        # Bibliography database
├── sections/             # Chapter/section content (01_xxx.tex, ...)
├── appendices/           # Appendix content (A_xxx.tex, ...)
├── figures/              # All image assets
└── .vscode/
    └── settings.json     # VS Code visual hiding rules
```

## Multi-Version Architecture (Conferences)

For projects with different submission requirements (e.g., ICRA vs. IROS), use multiple entry points sharing the same content.

### Directory Layout
```
Project_Root/
├── main_icra.tex         # ICRA entry point
├── main_iros.tex         # IROS entry point
├── Makefile              # Handles targets: all, icra, iros, release
├── sections/             # Shared content
│   ├── 01_intro.tex
│   └── ...
└── ...
```

### Makefile for Multi-Version
```makefile
VERSIONS = icra iros
.PHONY: all clean release $(VERSIONS)

all: $(VERSIONS)

# Rule to compile a specific version: make icra -> compiles main_icra.tex
$(VERSIONS):
	latexmk -pdf -xelatex main_$@.tex

release: all
	cp main_icra.pdf author-2026-icra-submission.pdf
	cp main_iros.pdf author-2026-iros-submission.pdf
	@echo "Submission versions ready."

clean:
	latexmk -C
	rm -f *.pdf *.xdv *.synctex.gz
```

### Conditional Content
Use simple `\newcommand` or the `etoolbox` package in entry points to toggle content.

**In main_icra.tex:**
```latex
\newcommand{\conference}{ICRA}
\input{sections/01_intro}
```

**In sections/01_intro.tex:**
```latex
\ifdefstring{\conference}{ICRA}{
    This text is specific to ICRA.
}{
    This text is for other versions.
}
```

## VS Code settings.json (Visual Hiding)

```json
{
    "files.exclude": {
        "**/*.aux": true,
        "**/*.fdb_latexmk": true,
        "**/*.fls": true,
        "**/*.log": true,
        "**/*.out": true,
        "**/*.synctex.gz": true,
        "**/*.xdv": true,
        "**/*.bbl": true,
        "**/*.blg": true,
        "**/*.run.xml": true,
        "**/*.bcf": true
    }
}
```

## .gitignore

```gitignore
*.aux
*.log
*.out
*.fls
*.fdb_latexmk
*.synctex.gz
*.bbl
*.blg
*.xdv
*.run.xml
*.bcf
```
