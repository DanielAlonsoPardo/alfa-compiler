#nasm -g -o o.o -f elf out.out; gcc o.o alfalib.o -o a

all: bison flex compilador


compilador: alfa.c flex bison
	####################################
	#Compilando el compilador
	####################################
	gcc -Wall -Wno-unused-function -g parser.c tokens.c alfa.c th.c -o alfa
flex: alfa.l
	####################################
	#Compilando el analizador léxico
	####################################
	flex -o tokens.c alfa.l
bison: alfa.y
	####################################
	#Compilando el analizador sintáctico
	####################################
	bison -o parser.c -dvy alfa.y

%.c: %.y
%.c: %.l

clean:
	rm -fr alfa parser.output tokens.c parser.c parser.h

help:
	####################################
	#Ejemplos de uso:
	####################################
	#
	# ./alfa ./programas\ de\ prueba/ej_aritmeticas1.alf a.asm
	#
	# nasm -g -o a.o -f elf a.asm
	#
	# gcc -o a a.o alfalib.o
	#
	## Compilar para una máquina de 64bit:
	#
	# gcc -o a a.o alfalib.o -m32
