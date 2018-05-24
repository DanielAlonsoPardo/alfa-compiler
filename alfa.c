#include "alfa.h"
#include <stdio.h>

extern FILE *yyin, *yyout;
extern int yyparse();

int main(int argc, char *argv[])
{
  /*comprobación de paso de argumentos */
  switch(argc)
    {
    case 1: /*yyin y yyout estandar*/
      yyin = stdin;
      yyout = stdout;
      break;

    case 2: /*yyout estandar + arg como yyin*/
      yyin = fopen(argv[1],"r");
      if (!yyin)
	{
	  printf("No es posible abrir el fichero: %s\n", argv[1]);
	  return ERR;
	}
      yyout = stdout;
      break;

    case 3: /*1er arg yyin 2do yyout*/
      yyin = fopen(argv[1],"r");
      if (!yyin)
	{
	  printf("No es posible abrir el fichero: %s\n", argv[1]);
	  return ERR;
	}
      yyout = fopen(argv[2],"w");
      if (!yyout)
	{
	  printf("No es posible abrir el fichero: %s\n", argv[2]);
	  fclose(yyin);
	  return ERR;
	}
      break;

    default: /*argumentos incorrectos*/	
      printf("compilador [<fichero_entrada> [<fichero_salida]]\n>"); 
      return ERR;
    }

  yyparse();

  fclose(yyin);
  fclose(yyout);
  return OK;
}
