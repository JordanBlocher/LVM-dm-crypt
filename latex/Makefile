all: latex

latex: report.pdf 

clean:
	rm -f *.dvi *.aux *.log *.bbl

report.dvi: report.tex report.bib 
	latex report.tex
	bibtex report
	latex report.tex

report.pdf: report.dvi
	latex report.tex
	dvipdfm report.dvi
