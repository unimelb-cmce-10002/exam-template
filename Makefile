.PHONY: all student solutions clean

all: student solutions

student:
	quarto render exam.qmd --profile student

solutions:
	quarto render exam.qmd --profile solutions

clean:
	rm -rf _output .quarto
