LATEXMK = latexmk -cd -pdf -interaction=nonstopmode

MANUAL_ROOT = assets/manual

LUA_SRCS = $(wildcard advtrains*/*.lua)

TEX_PATH = $(MANUAL_ROOT)/tex
TEX_ALL_SRCS = $(wildcard $(TEX_PATH)/*.tex)
TEX_MAIN_SRCS = $(wildcard $(TEX_PATH)/*manual.tex)
TEX_MAIN_DSTS = $(TEX_MAIN_SRCS:%.tex=%.pdf)

all: doc

doc: doc-pdf doc-ldoc

doc-pdf: $(TEX_MAIN_DSTS)
%.pdf:: %.tex $(TEX_ALL_SRCS)
	$(LATEXMK) $<

doc-ldoc:: $(LUA_SRCS)
	ldoc .
	tar cJf assets/manual/ldoc.tar.xz -C assets/manual/ldoc_output .
