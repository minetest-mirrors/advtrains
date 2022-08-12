PANDOC = pandoc
LATEX = pdflatex
LATEXMK = latexmk
LUA = luajit

MANUAL_ROOT = assets/manual

MAN_PATH = $(MANUAL_ROOT)/man
MAN_SRCS = $(wildcard $(MAN_PATH)/*/*.md)
MAN_DSTS = $(MAN_SRCS:%.md=%)
MAN_TEXS = $(MAN_SRCS:%.md=%.tex)
MAN_FILTER = $(MANUAL_ROOT)/filter_man.lua

TEX_PATH = $(MANUAL_ROOT)/tex
MAN_TEX_DIR = $(TEX_PATH)/man
MAN_TEX = $(TEX_PATH)/man.tex
TEX_MAIN_SRCS = $(wildcard $(TEX_PATH)/*manual.tex)
TEX_MAIN_DSTS = $(TEX_MAIN_SRCS:%.tex=%.pdf)

all: doc

doc: doc-pdf doc-man

doc-pdf: $(TEX_MAIN_DSTS)
%.pdf: %.tex $(MAN_TEX) $(wildcard $(TEX_PATH)/*.tex)
	$(LATEXMK) -cd -pdf $<

doc-man: $(MAN_DSTS)
	find assets/manual/man -regex '.*/[^.]+\.[^.]+$$' | tar -cJf ${MANUAL_ROOT}/man.tar.xz -T -

%:: %.md ${MAN_FILTER}
	$(PANDOC) -L ${MAN_FILTER} -s -t man -o $@ $<

%.tex:: %.md ${MAN_FILTER}
	$(PANDOC) -L ${MAN_FILTER} -t latex -o $(MAN_TEX_DIR)/$(notdir $@) $<

$(MAN_TEX): $(MAN_TEXS)
	find $(MAN_TEX_DIR) -name '*.tex' -printf '\\include{man/%f}\n' | sort | sed '1s/^\\include/\\input/' > $(MAN_TEX)
