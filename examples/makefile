#nasm -g -o o.o -f elf out.out; gcc o.o alfalib.o -o a

all: compiler mkall tryall

compiler:
	make -C ..
	mv ../alfa .
	make -C .. clean

mkall: mk1 mk2 mk3 mk4 mk5
tryall:
	########################
	##Executing exe1
	########################
	-./exe1
	########################
	##Executing exe2
	########################
	-./exe2
	########################
	##Executing exe5
	########################
	-./exe5

mk1:
	-./alfa ej1.alf exe1.asm
	nasm -g -o exe1.o -f elf exe1.asm
	gcc -o exe1 exe1.o ../alfalib.o -m32
mk2:
	-./alfa ej2.alf exe2.asm
	nasm -g -o exe2.o -f elf exe2.asm
	gcc -o exe2 exe2.o ../alfalib.o -m32
mk3:
	-./alfa ej3.alf exe3.asm
	########################
	##This example is meant to fail compilation
	########################
mk4:
	-./alfa ej4.alf exe4.asm
	########################
	##This example is meant to fail compilation
	########################
mk5:
	-./alfa ej5.alf exe5.asm
	nasm -g -o exe5.o -f elf exe5.asm
	gcc -o exe5 exe5.o ../alfalib.o -m32

clean:
	rm -f *.asm *.o exe* alfa
