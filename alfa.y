%{
#include <stdio.h>
#include <string.h>
#include "alfa.h"
#include "th.h"
  
#define GLOBAL 0
#define LOCAL 1
  
#define SINTACTICO 0
#define MORFOLOGICO 1
#define SEMANTICO 2
#define OTRO 3
  
  extern int yylex();
  extern FILE *yyout;
  int flag_error = 0;
  int numero_fila = 1;
  int numero_col = 0;
  th *local, *global;
  int ambito = GLOBAL;
  int local_pos = 1;//identifica el orden que ocupa una variable local, empieza siempre en 0.
  //ambito == global hasta que se termina de leer las variables en la sección de variables globales del programa.
  //En escritura_segmentos se cambia a local, y al principio y al final de cada función declarada y de main, se crea y destruye respectivamente una th local.
  int arg_pos = 0;//lo mismo pero para argumentos
  int etiqueta;
  int etiqueta_if=0;
  int etiqueta_else=0;
  int tag_repeat=0;
  char morf_err[256];

  elem* func_local = NULL;

  /*A esta función solo la llama cuando realmente hay un error de bison o de lex!! Pero no cuando hay un semántico. Habrá que hacer otra funcion pa eso*/
  /*JAJA un poco tarde para eso último */
  void yyerror (const char* err_description)
  {
    switch(flag_error)
      {
      case 1:
	fprintf(stderr, "ERROR MORFOLOGICO:%d:%d:%s\n", numero_fila, numero_col, morf_err);
	return;
	break;
      case 2:fprintf(stderr, "ERROR SEMANTICO:%d:%d:", numero_fila, numero_col);
	break;
      case 3:fprintf(stderr, "ERROR GENERAL:");
	break;
      default:fprintf(stderr, "ERROR SINTACTICO:%d:%d:\n", numero_fila, numero_col);
	return;
	break;
      }
    if (err_description != NULL)
      fprintf(stderr, "%s", err_description);
    fprintf(stderr, "\n");
  }
	
  elem* buscar_simbolo(char* clave)
  {
    elem* this;
    this = buscar_th(local, clave);
    if (this == NULL)
      this = buscar_th(global, clave);
    return this;
  }

  elem* buscar_simbolo_gl(char* clave, int* loc)
  {
    elem* this;
    this = buscar_th(local, clave);
    if (this == NULL)
      {
	this = buscar_th(global, clave);
	*loc = GLOBAL;
      }
    else
      *loc = LOCAL;
    return this;
  }
%}

%union 
{
  tipo_atributos atributos;
}

/*Axioma*/
%start programa

/*Palabras reservadas*/
%token TOK_abrir_programa
%token TOK_abrir_variables
%token TOK_abrir_funciones
%token TOK_abrir_main
%token TOK_abrir_args
%token TOK_abrir_if
%token TOK_abrir_else
%token TOK_abrir_repeat

%token TOK_personalizado
%token TOK_exp_personalizado
	
%token TOK_abrir_lista

%token TOK_programa
%token TOK_variables
%token TOK_funciones
%token TOK_main
%token TOK_args
%token TOK_if
%token TOK_else
%token TOK_repeat
%token TOK_lista

%token TOK_name
%token TOK_condition
%token TOK_until
%token TOK_scanf
%token TOK_printf
%token TOK_return
%token TOK_insert_front
%token TOK_insert_back
%token TOK_empty
%token TOK_extraccion_principio
%token TOK_extraccion_final
%token TOK_is_empty
%token TOK_size_of
%token TOK_cerrar_tag

%token <atributos> TOK_var_ent
%token <atributos> TOK_var_logica

/*Simbolos*/
%token TOK_and
%token TOK_or
%token TOK_igual_a
%token TOK_diferente_de
%token TOK_menor_igual
%token TOK_mayor_igual
%token TOK_en
%token <atributos> TOK_true
%token <atributos> TOK_false
	   
/*Otros*/
%token <atributos> TOK_ID
%token <atributos> TOK_constante

/*No terminales con atributos semanticos*/
%type <atributos> exp_personalizado

%type <atributos> repeat_part1
%type <atributos> declaracion_argumentos
%type <atributos> argumentos
%type <atributos> variables
%type <atributos> declaraciones

%type <atributos> lista_exp
%type <atributos> resto_exp
%type <atributos> tipo
%type <atributos> info_lista
%type <atributos> constante_entera
%type <atributos> constante_logica
%type <atributos> constante
%type <atributos> comparacion
%type <atributos> exp
%type <atributos> identificador
%type <atributos> exp_identificador
%type <atributos> retorno_funcion
%type <atributos> asignacion

/*Reglas de prioridad*/
%left '+' '-' TOK_or
%left '*' '/' TOK_and
%left '^'
%left TOK_exp_personalizado
%right MenosU '!'

/*REGLAS*/
%%
programa: inicializar TOK_abrir_programa'>' variables escritura_segmentos funciones main TOK_cerrar_tag TOK_programa'>'
	{ fprintf(yyout, ";R1:\t\"programa\" ::= <programa> \"variables\" \"funciones\" \"main\" </programa>\n");
	fprintf(yyout, "fin:\n");
	fprintf(yyout, "mov esp, ebp\n");
	fprintf(yyout, "pop ebp\n");
	fprintf(yyout, "ret");
	/*Liberar memo!*/
	libera_th(&global);
	}
	;

inicializar: 
	{ /*Inicializaciones*/
	  /*Abrir fichero*/
	  /*Inicializar tabla de simbolos*/
	  //[FINISH] Detectar errores al crear_th
	  //y encontrar automáticamente el tamaño requerido para la tabla hash
	  //en vez de usar DEFAULT_TH_TAM
	  global = crear_th (DEFAULT_TH_TAM, "global");
	  if (global == NULL)
	    {
	      flag_error = OTRO;
	      yyerror("Error en crear_th()\n");
	      YYABORT;
	    }
	  ambito = GLOBAL;//el ámbito se mantiene global para la declaración de variables
	                  //hasta llegar a las funciones y/o a main, que cambian el ámbito a local.
	  etiqueta = 0;
	};

escritura_segmentos:
	{
	  int i;
	  elem* current = global->tabla;
	  /*Segmento bss*/
	  fprintf(yyout, ";--BSS SEGMENT--;\n");
	  fprintf(yyout, "segment .bss\n"); 
	  fprintf(yyout, "_auxint resd 1\n");
	/*Imprime las variables almacenadas en la tabla hash*/	

	  for (i = 0; i < DEFAULT_TH_TAM; i++)
	    {
	      current = &(global->tabla[i]);
	      while (current != NULL)
		{
		  if (current->categoria == VARIABLE)
		    fprintf(yyout, "_%s resd 1\n", current->clave);
		  current = current->siguiente;
		}
	    }


	/*Segmento de datos*/
	fprintf(yyout,";--DATA SEGMENT--;\n");
	fprintf(yyout,"segment .data\n");
	fprintf(yyout,"mensaje_E db \"ERROR DE EJECUCION: Division por cero\",0\n");
	fprintf(yyout,"mensaje_E_M db \"ERROR DE EJECUCION: Llamada a malloc fallida\",0\n");
	fprintf(yyout,"mensaje_E_EX db \"ERROR DE EJECUCION: Intento de extracción a una lista vacía\",0\n");
	//	fprintf(yyout,"mensaje_aviso db \"AVISO: \",0\n");

	/*Segmento de texto*/
	fprintf(yyout, ";--TEXT SEGMENT--;\n");
	fprintf(yyout,"segment .text\n");
	fprintf(yyout,"global main\n");
	fprintf(yyout,"extern scan_int, scan_boolean\n");
	fprintf(yyout,"extern print_int, print_boolean, print_string, print_blank, print_endofline\n");
	fprintf(yyout, "extern malloc, free\n");

	/*Ahora vienen las funciones*/
	fprintf(yyout, ";--FUNCIONES--;\n");
	};

escritura_main:
	{ 
	/*errores(como final de funciones)*/
	/*division por 0*/
	fprintf(yyout, ";--ERRORS--;\n");
	fprintf(yyout, "error_E: push dword mensaje_E\n");
	fprintf(yyout, "call print_string\n");
	fprintf(yyout, "call print_endofline\n");
	fprintf(yyout, "add esp, 8\n");
	fprintf(yyout, "jmp near fin\n");

	fprintf(yyout, "error_E_M: push dword mensaje_E_M\n");
	fprintf(yyout, "call print_string\n");
	fprintf(yyout, "call print_endofline\n");
	fprintf(yyout, "add esp, 8\n");
	fprintf(yyout, "jmp near fin\n");

	fprintf(yyout, "error_E_EX: push dword mensaje_E_EX\n");
	fprintf(yyout, "call print_string\n");
	fprintf(yyout, "call print_endofline\n");
	fprintf(yyout, "add esp, 8\n");
	fprintf(yyout, "jmp near fin\n");


	fprintf(yyout, ";--LIST FUNCS--\n");
	/************/
	fprintf(yyout, "list_last_elem:\n");
	fprintf(yyout, ";returns in eax pointer to last elem\n");
	fprintf(yyout, ";0 if no elements\n");

	fprintf(yyout, "push dword ebp\n");
	fprintf(yyout, "mov ebp, esp\n");

	fprintf(yyout, "mov dword eax, [ebp+8]\n");
	fprintf(yyout, "list_last_elem_begin:\n");
	fprintf(yyout, "cmp dword [eax], 0\n");
	fprintf(yyout, "je list_last_elem_end\n");

	fprintf(yyout, "mov eax, [eax]\n");

	fprintf(yyout, "jmp list_last_elem_begin\n");
	fprintf(yyout, "list_last_elem_end:\n");

	fprintf(yyout, "mov esp, ebp\n");
	fprintf(yyout, "pop ebp\n");
	fprintf(yyout, "ret\n");

	/*penult*/
	fprintf(yyout, "list_penlast_elem:\n");
	fprintf(yyout, ";returns in eax pointer to second to last elem\n");
	fprintf(yyout, ";0 if no elements\n");

	fprintf(yyout, "push dword ebp\n");
	fprintf(yyout, "mov ebp, esp\n");

	fprintf(yyout, "mov dword eax, [ebp+8]\n");
	fprintf(yyout, "list_penlast_elem_begin:\n");
	fprintf(yyout, "mov dword edx, [eax]\n");
	fprintf(yyout, "cmp dword [edx], 0\n");
	fprintf(yyout, "je list_penlast_elem_end\n");

	fprintf(yyout, "mov eax, [eax]\n");

	fprintf(yyout, "jmp list_penlast_elem_begin\n");
	fprintf(yyout, "list_penlast_elem_end:\n");

	fprintf(yyout, "mov esp, ebp\n");
	fprintf(yyout, "pop ebp\n");
	fprintf(yyout, "ret\n");



	/************/
	
	/*Comienza el MAIN*/
	fprintf(yyout, ";--MAIN PROCESS--;\n");
	fprintf(yyout, "main:\n");
	fprintf(yyout, "push 0\n");
	fprintf(yyout, "mov ebp, esp\n");
	};

variables: TOK_abrir_variables'>' declaraciones TOK_cerrar_tag TOK_variables'>'
	{ fprintf(yyout, ";R2:\t\"variables\" ::= <variables> \"declaraciones\" </variables>\n");
	  $$.valor_entero = $3.valor_entero;}
	|
	{ fprintf(yyout, ";R2.1:\t\"variables\" ::= \n");}
	;

declaraciones: declaracion declaraciones
	{ fprintf(yyout, ";R3:\t\"declaraciones\" ::= \"declaracion\" \"declaraciones\"\n");
	  $$.valor_entero = 1 + $2.valor_entero;}
	| declaracion 
	{fprintf(yyout,";R3:\t\"declaraciones\" ::= \"declaracion\" \"declaraciones\"\n");
	  $$.valor_entero = 1;}
	;

declaracion: declaracion_escalar
        {
	  fprintf(yyout, ";R4:\t\"declaracion\" ::= \"declaracion_escalar\"\n");}
	| declaracion_lista
	{ fprintf(yyout, ";R4.1:\t\"declaracion\" ::= \"declaracion_lista\"\n");}
	;

declaracion_escalar: '<' tipo TOK_name'='identificador'>'constante TOK_cerrar_tag tipo '>'
{
	  elem obj;
	  fprintf(yyout, ";R5:\t\"declaracion_escalar\" ::= <\"tipo\" name='\"identificador\"'>\"constante\"</\"tipo\">\n");
	  /*Comprobación semantica de tipos correctos*/
	  if($2.tipo != $9.tipo)
	    {
	      flag_error = 2; 
	      yyerror("Los tags de apertura y cierre deben ser del mismo tipo.");
	    }

	  strncpy(obj.clave, $5.lexema, MAX_CLAVE + 1);
	  obj.categoria = VARIABLE;
	  obj.tipo = $2.tipo;
	  obj.clase = ESCALAR;
	  obj.num_parametros = 0;
	  obj.pos_parametro = 0;
	  obj.num_var_locales = 0;
	  obj.pos_var_local = (ambito == LOCAL) ? local_pos : -1;     //si es var local, posicion
	  obj.siguiente = NULL;
	  obj.valor_init = $7.valor_entero;
	  
	  if (ambito == LOCAL)
	    {
	      if (insertar_th(local, &obj) == -1)
		{
		  char msg[MAX_CLAVE * 2];
		  sprintf(msg, "Declaracion duplicada (%s)", obj.clave);
		  flag_error = SEMANTICO;
		  yyerror(msg);
		  YYABORT;
		}
	      local_pos++;
	    } else if (ambito == GLOBAL) {
	    if (insertar_th(global, &obj) == -1)
	      {
		char msg[MAX_CLAVE * 2];
		sprintf(msg, "Declaracion duplicada (%s)", obj.clave);
		flag_error = SEMANTICO;
		yyerror(msg);
		YYABORT;
	      }
	    }
	  if (func_local == NULL)
	    fprintf(yyout,"push dword %d\n", obj.valor_init);
    }
	;

tipo: TOK_var_logica
	{ fprintf(yyout, ";R6:\t\"tipo\" ::= logico\n");
	  $$.tipo = BOOLEAN;}
	| TOK_var_ent
	{ fprintf(yyout, ";R6.1:\t\"tipo\" ::= entero\n");
	  $$.tipo = INT;}
	;

/*Las listas no se pueden inicializar*/
/*[lista] -> puntero*/
/*[lista + 4] -> valor*/
declaracion_lista: TOK_abrir_lista TOK_name'='identificador'>' TOK_cerrar_tag TOK_lista'>'
	{
	  elem obj;
	  fprintf(yyout, ";R7:\t\"declaracion_lista\" ::= <lista name='\"identificador\"'>\"\"</lista>\n");

	  strncpy(obj.clave, $4.lexema, MAX_CLAVE + 1);
	  obj.categoria = VARIABLE;
	  obj.tipo = LISTA;
	  obj.clase = LISTA;
	  obj.num_parametros = 0;
	  obj.pos_parametro = 0;
	  obj.num_var_locales = 0;
	  obj.pos_var_local = (ambito == LOCAL) ? local_pos : -1;     //si es var local, posicion
	  obj.siguiente = NULL;
	  obj.valor_init = 0;
	  
	  if (ambito == LOCAL)
	    {
	      if (insertar_th(local, &obj) == -1)
		{
		  char msg[MAX_CLAVE * 2];
		  sprintf(msg, "Declaracion duplicada (%s)", obj.clave);
		  flag_error = SEMANTICO;
		  yyerror(msg);
		  YYABORT;
		}
	      local_pos++;
	    } else if (ambito == GLOBAL) {
	    if (insertar_th(global, &obj) == -1)
	      {
		char msg[MAX_CLAVE * 2];
		sprintf(msg, "Declaracion duplicada (%s)", obj.clave);
		flag_error = SEMANTICO;
		yyerror(msg);
		YYABORT;
	      }
	    }
	  if (func_local == NULL)
	    fprintf(yyout,"push dword 8\n");
	    fprintf(yyout,"call malloc\n");
	    fprintf(yyout,"pop dword ecx\n");

	    fprintf(yyout,"push dword eax\n");

	    fprintf(yyout,"mov dword [eax], 0\n");
	    fprintf(yyout,"mov dword [eax + 4], 0\n");
    }
	;

funciones: TOK_abrir_funciones'>'  declaracion_funciones TOK_cerrar_tag TOK_funciones'>'
	{ fprintf(yyout, ";R8:\t\"funciones\" ::= <funciones> \"declaracion_funciones\" </funciones>\n");}
	| 
	{ fprintf(yyout, ";R8.1:\t\"funciones\" ::=\n");}
	;
	
declaracion_funciones: declaracion_funcion declaracion_funciones
	{ fprintf(yyout, ";R9:\t\"declaracion_funciones\" ::= \"declaracion_funcion\"\"declaracion_funciones\"\n");}
	| declaracion_funcion 
	{fprintf(yyout, ";R9:\t\"declaracion_funciones\" ::= \"declaracion_funcion\"\"declaracion_funciones\"\n");}
	;

funcion_open: '<' tipo TOK_name'='identificador '>' ts_local_start declaracion_argumentos variables
        {
	  elem obj;
	  int i;
	  elem* current = NULL;
	  strncpy(obj.clave, $5.lexema, MAX_CLAVE + 1);
	  obj.categoria = FUNCION;
	  obj.tipo = $2.tipo;
	  obj.clase = ESCALAR;
	  obj.num_parametros = $8.valor_entero;
	  obj.pos_parametro = 0;
	  obj.num_var_locales = $9.valor_entero;
	  obj.pos_var_local = 0;     //si es var local, posicion
	  obj.siguiente = NULL;

	  if (insertar_th(global, &obj) == -1)
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg, "Declaracion duplicada (%s)", obj.clave);
	      flag_error = SEMANTICO;
	      yyerror(msg);
	      YYABORT;
	    }
	  func_local = buscar_th(global, obj.clave);
	  //comienzo función
	  fprintf(yyout, "_%s:\n", obj.clave);
	  fprintf(yyout, "push dword ebp\n");
	  fprintf(yyout, "mov ebp, esp\n");
	  fprintf(yyout, "sub esp, %d\n", 4 * obj.num_var_locales);

	  //inicialización de variables locales
	  for (i = 0; i < DEFAULT_TH_TAM; i++)
	    {
	      current = &(local->tabla[i]);
	      while (current != NULL)
		{
		  if (current->categoria == VARIABLE)
		    fprintf(yyout, "mov dword [ebp-%d], %d\n", (current->pos_var_local * 4), current->valor_init);
		  current = current->siguiente;
		}
	    }
	}

declaracion_funcion: funcion_open sentencias ts_local_stop TOK_cerrar_tag tipo '>'
	{ fprintf(yyout, ";R11:\t\"declaracion_funcion\" ::= <\"tipo\" name='\"identificador\"'> \"declaracion_argumentos\" \"variables\" \"sentencias\" </\"tipo\">\n");
	  fprintf(yyout, "mov esp, ebp\n");
	  fprintf(yyout, "pop ebp\n");
	  fprintf(yyout, "ret\n");
	}
	;
main_init_vars: variables
        {
/* 	  int i; */
/* 	  int count = 0; */
/* 	  elem* current; */

/* 	  for (i = 0; i < DEFAULT_TH_TAM; i++) */
/* 	    { */
/* 	      current = &(local->tabla[i]); */
/* 	      while (current != NULL) */
/* 		{ */
/* 		  if (current->categoria == VARIABLE) */
/* 		    { */
/* 		      fprintf(yyout, "mov dword [ebp-%d], %d\n", (current->pos_var_local * 4), current->valor_init); */
/* 		      count++; */
/* 		    } */
/* 		  current = current->siguiente; */
/* 		} */
/* 	    } */
	}
        ;
main: TOK_abrir_main'>' ts_local_start escritura_main main_init_vars sentencias ts_local_stop TOK_cerrar_tag TOK_main'>'
	{ fprintf(yyout, ";R10:\t\"main\" ::= <main>\"variables\"\"sentencias\"</main>\n");}
	;

ts_local_start:
	{
	  local_pos = 1;
	  arg_pos = 0;
	  ambito = LOCAL;
	  local = crear_th(DEFAULT_TH_TAM, "local");
	  if (local == NULL)
	    {
	      flag_error = OTRO;
	      yyerror("Error en crear_th()\n");
	      YYABORT;
	    }

	};
ts_local_stop:
	{
	  func_local = NULL;
	  local_pos = 1;
	  libera_th(&local);
	  arg_pos = 0;
	};

declaracion_argumentos: TOK_abrir_args'>' argumentos TOK_cerrar_tag TOK_args'>'
	{ fprintf(yyout, ";R12:\t\"declaracion_argumentos\" ::= <args> \"argumentos\" </args>\n");
	  $$.valor_entero = $3.valor_entero;}
	|
	{ fprintf(yyout, ";R12.1:\t\"declaracion_argumentos\" ::= \n");
	  $$.valor_entero = 0;}
	; 

argumentos: argumento argumentos
	{ fprintf(yyout, ";R13:\t\"argumentos\" ::= \"argumento\"\"argumentos\"\n");
	  $$.valor_entero = 1 + $2.valor_entero;}
	| argumento
	{ fprintf(yyout, ";R13:\t\"argumentos\" ::= \n");
	  $$.valor_entero = 1;}
	;

argumento: '<'tipo TOK_name'='identificador'>' TOK_cerrar_tag tipo'>' 
	{
	  elem obj;
	  fprintf(yyout, ";R13:\t\"argumento\" ::= \"tipo\" name = \"identificador\" \n");

	  strncpy(obj.clave, $5.lexema, MAX_CLAVE + 1);
	  obj.categoria = PARAMETRO;
	  obj.tipo = $2.tipo;
	  obj.clase = ESCALAR;
	  obj.num_parametros = 0;
	  obj.pos_parametro = arg_pos;
	  obj.num_var_locales = 0;
	  obj.pos_var_local = 0;     //si es var local, posicion
	  obj.siguiente = NULL;

	  if (insertar_th(local, &obj) == -1)
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg, "Declaracion duplicada (%s)", obj.clave);
	      flag_error = SEMANTICO;
	      yyerror(msg);
	      YYABORT;
	    }
	  arg_pos++;
}
	;

sentencias: sentencia sentencias
	{ fprintf(yyout, ";R14:\t\"sentencias\" ::= \"sentencia\" \"sentencias\"\n");}
	|
	{ fprintf(yyout, ";R14.1:\t\"sentencias\" ::= \"sentencia\"\n");}
	;

sentencia: sentencia_simple ';'
	{ fprintf(yyout, ";R15:\t\"sentencia\" ::= \"sentencia_simple\"\n");}
	| bloque 
	{ fprintf(yyout, ";R15.1:\t\"sentencia\" ::= \"bloque\"\n");}
	;

sentencia_simple: asignacion
	{ fprintf(yyout, ";R16:\t\"sentencia_simple\" ::= \"asignacion\"\n");}
	| lectura
	{ fprintf(yyout, ";R16.1:\t\"sentencia_simple\" ::= \"lectura\"\n");}
	| exp
	{ fprintf(yyout, ";R16.1:\t\"sentencia_simple\" ::= \"exp\"\n");}
	| escritura
	{ fprintf(yyout, ";R16.2:\t\"sentencia_simple\" ::= \"escritura\"\n");}
	| retorno_funcion
	{ fprintf(yyout, ";R16.4:\t\"sentencia_simple\" ::= \"retorno_funcion\"\n");}
	| operacion_lista
	{ fprintf(yyout, ";R16.5:\t\"sentencia_simple\" ::= \"operacion_lista\"\n");}
	| personalizado
	{ fprintf(yyout, ";R16.5:\t\"sentencia_simple\" ::= \"personalizado\"\n");}
	;

bloque: condicional
	{ fprintf(yyout, ";R17:\t\"bloque\" ::= \"condicional\"\n");}
	| bucle
	{ fprintf(yyout, ";R17.1:\t\"bloque\" ::= \"blucle\"\n");}
	;

asignacion: identificador '=' exp	
	{
	  elem* this;
	  int loc;
	  fprintf(yyout, ";R18:\t\"asignacion\" ::= \"identificador\" = \"exp\"\n");
	  this = buscar_simbolo_gl($1.lexema, &loc);
	  if (this == NULL)
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg, "Intento de acceso a una variable no declarada (%s)", $1.lexema);
	      flag_error=SEMANTICO;
	      yyerror(msg);
	      YYABORT;
	    }
	  if (this->categoria == FUNCION)
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg, "Intento equivocado de acceso a una funcion como si fuera una variable.(%s)", $1.lexema);
	      flag_error = SEMANTICO;
	      yyerror(msg);
	      YYABORT;
	    }
	  if (this->tipo != $3.tipo)
	    {
	      flag_error = SEMANTICO;
	      yyerror("Asignacion incompatible");
	      YYABORT;
	    }

	  if (loc == LOCAL)
	    {
	      switch (this->categoria)
		{
		case PARAMETRO:
		  fprintf(yyout, "pop dword eax\n");
		  fprintf(yyout, "mov [ebp+%d]\n, eax", (1 + (func_local->num_parametros - (this->pos_parametro))) * 4);
		  break;
		case VARIABLE:
		  fprintf(yyout, "pop dword eax\n");
		  fprintf(yyout, "mov [ebp-%d], eax\n", this->pos_var_local * 4);
		  break;
		}
	    }
	  else
	    {
	      fprintf(yyout, "pop dword eax\n");
	      fprintf(yyout, "mov [_%s], eax\n", this->clave);
	    }

}
	;

condicional: TOK_abrir_if TOK_condition'='exp'>' if_part1 sentencias TOK_cerrar_tag TOK_if'>' 
	{
	  fprintf(yyout, ";R19:\t\"condicional\" ::= <if condition='\"exp\"'> \"sentencias\" </if>\n");
        //comprobacion semantica
	  if ($4.tipo != BOOLEAN)
	    {
	      flag_error = SEMANTICO;
	      yyerror("Sentencia condicional con condición de tipo incorrecto");
	      YYABORT;
	    }
	  //Generacion de codigo
	  fprintf(yyout, "if_end%d:\n", etiqueta_if);
	}
        | TOK_abrir_if TOK_condition'='exp'>' if_part1 sentencias TOK_cerrar_tag TOK_if'>' if_part2 TOK_abrir_else'>' sentencias TOK_cerrar_tag TOK_else'>'
        {
	  fprintf(yyout, ";R19.1:\t\"condicional\" ::= <if condition='\"exp\"'> \"sentencias\" </if><else> \"sentencias\" </else>\n");
	  //comprobacion semantica
	  if ($4.tipo != BOOLEAN)
	    {
	      flag_error = SEMANTICO;
	      yyerror("Sentencia condicional con condición de tipo incorrecto");
	      YYABORT;
	    }
     	etiqueta_else++;
	  fprintf(yyout, "else_end%d:\n", etiqueta_else);
    }
	;
    
if_part1:
    {   
        //reserva de etiqueta
        etiqueta_if++;
        
        //Generacion de codigo
        fprintf(yyout, "pop eax\n");
        fprintf(yyout, "cmp eax, 0\n");
        fprintf(yyout, "je near if_end%d\n", etiqueta_if);
    }
    ;
    
if_part2:
    {
        //Generacion de codigo
        fprintf(yyout, "jmp near else_end%d\n", etiqueta_if);
        fprintf(yyout, "if_end%d:\n", etiqueta_if);
    }
    ;


bucle: TOK_abrir_repeat repeat_part1 TOK_until'='exp'>' repeat_part2 sentencias TOK_cerrar_tag TOK_repeat'>'
	{
	  fprintf(yyout, ";R20:\t\"bucle\" ::= <repeat until='\"exp\"'> \"sentencias\" </repeat>\n");
	  if ($5.tipo != BOOLEAN)
	    {
	      flag_error = SEMANTICO;
	      yyerror("Sentencia iterativa con condición de tipo incorrecto");
	      YYABORT;
	    }


      fprintf(yyout, "jmp near ini_repeat%d\n", $2.valor_entero);
      fprintf(yyout, "ini_end%d:\n", $2.valor_entero);
    }
	;

repeat_part1:
    {
      tag_repeat++;
      $$.valor_entero = tag_repeat;

      fprintf(yyout, "jmp near ini_post_repeat_%d\n", tag_repeat);
      fprintf(yyout, "ini_repeat%d:\n", tag_repeat);
    }
    ;


repeat_part2:
    {
      fprintf(yyout, "pop eax\n");
      fprintf(yyout, "cmp eax, 1\n");
      fprintf(yyout, "je near ini_end%d\n", tag_repeat);

      //code
      fprintf(yyout, "ini_post_repeat_%d:\n", tag_repeat);
    }
    ;

personalizado: TOK_personalizado exp_identificador TOK_en exp_identificador
         {
	   /*[CLONAR exp EN exp]*/
	   /*[para el examen de extraordinaria de PAUTLEN]*/
	  fprintf(yyout, ";R22:\t\"personalizado\" ::= personalizado(\"exp\",\"exp\")\n");

	  if (($4.tipo != LISTA) || ($2.tipo != LISTA))
	    {
	      flag_error=2;
	      yyerror("La clonación sólo se puede realizar con variables de tipo estructurado");
	      YYABORT;
	    }

	  /*clone list a into list b*/
	  fprintf(yyout, "pop ebx\n");
	  fprintf(yyout, "pop eax\n");
	  fprintf(yyout, "push eax\n");
	  fprintf(yyout, "push ebx\n");


	  /*empty list b*/
	  /*
	    ebx = list pointer
	  */
	  fprintf(yyout, "begin_empty%d:\n", etiqueta);
	  fprintf(yyout, "mov ecx, [ebx]\n");
	  fprintf(yyout, "cmp ecx, 0\n");
	  fprintf(yyout, "je end_empty%d\n", etiqueta);
	  fprintf(yyout, "mov edx, [ecx]\n");
	  fprintf(yyout, "mov [ebx], edx\n");

	  fprintf(yyout, "push ecx\n");
	  fprintf(yyout, "call free\n");
	  fprintf(yyout, "add esp, 4\n");
	  fprintf(yyout, "jmp begin_empty%d\n", etiqueta);


	  fprintf(yyout, "end_empty%d:\n", etiqueta);
	  fprintf(yyout, "mov dword [ebx + 4], 0\n");

	  /*go through list a, find element, push into b then find next node*/
	  fprintf(yyout, "clone_begin%d:\n", etiqueta);
	  fprintf(yyout, "pop ebx\n");
	  fprintf(yyout, "pop eax\n");

	  /*does list a have more nodes left?*/
	  fprintf(yyout, "mov ecx, [eax]\n");

	  fprintf(yyout,"or ecx , ecx \n");
	  fprintf(yyout,"jz near fin_clon%d \n",etiqueta);

	  /*if so, move list a pointer forwards*/
	  fprintf(yyout, "push dword [eax]\n");
	  /*and insert value into end of list b*/
	  fprintf(yyout, "push dword [ecx+4]\n");
	  fprintf(yyout, "push ebx\n");
	  fprintf(yyout, "call list_last_elem\n");
	  fprintf(yyout, "push eax\n");

	  /*make room*/
	  fprintf(yyout, "push dword 8\n");
	  fprintf(yyout, "call malloc\n");
	  fprintf(yyout, "add esp, 4\n");

	  /*args*/
	  fprintf(yyout, "pop edx\n");
	  fprintf(yyout, "pop ebx\n");
	  fprintf(yyout, "pop ecx\n");

	  /*errcheck*/
	  fprintf(yyout, "cmp eax, 0\n");
	  fprintf(yyout, "je error_E_M\n");

	  /*connect new element*/
	  fprintf(yyout, "mov [edx], eax\n");
	  /*place values into new element*/
	  fprintf(yyout, "mov dword [eax], 0\n");
	  fprintf(yyout, "mov [eax+4], ecx\n");
	  /*update list element count*/
	  fprintf(yyout, "add dword [ebx+4], 1\n");

	  fprintf(yyout, "push ebx\n");

	  fprintf(yyout, "jmp near clone_begin%d\n", etiqueta);

	  /*loop*/



	  fprintf(yyout,"fin_clon%d: \n",etiqueta);


	  etiqueta++;
	 }

exp_personalizado: exp TOK_exp_personalizado exp
         {
	  fprintf(yyout, ";R22:\t\"exp_personalizado\" ::= exp_personalizado(\"exp\",\"exp\")\n");

	  if (($1.tipo != INT) || ($3.tipo != INT))
	    {
	      flag_error=2;
	      yyerror("Operacion aritmetica con operandos de tipo no permitido");
	      YYABORT;
	    }

	  $$.tipo = INT;
	  fprintf(yyout,"pop dword edx \n");
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"add eax, edx \n");
	  fprintf(yyout,"push dword eax \n");

	 }

lectura: TOK_scanf'('exp_identificador')'
         {
	   int loc;
	   elem* elem;
	   fprintf(yyout, ";R21:\t\"lectura\" ::= scanf(\"exp_identificador\")\n");
	   if ((elem = buscar_simbolo_gl($3.lexema, &loc)) == NULL) 
	     {
	       char msg[MAX_CLAVE * 2];
	       sprintf(msg,"Variable '%s' no declarada", $3.lexema); 
	       flag_error=SEMANTICO;
	       yyerror(msg);
	       YYABORT;
	     }
	   if (elem->categoria == FUNCION)
	     {
	       char msg[MAX_CLAVE * 2];
	       sprintf(msg,"Variable '%s' es una funcion, solo se acepta otras variables en scanf\n", $3.lexema); 
	       flag_error=SEMANTICO;
	       yyerror(msg);
	       YYABORT;
	     }

	  if (loc == LOCAL)
	    {
	      switch (elem->categoria)
		{
		case PARAMETRO:
		  fprintf(yyout, "mov eax, ebp\n");
		  fprintf(yyout, "add eax, %d\n", (1 + (func_local->num_parametros - (elem->pos_parametro))) * 4);
		  fprintf(yyout, "push dword eax");
		  break;
		case VARIABLE:
		  fprintf(yyout, "mov eax, ebp\n");
		  fprintf(yyout, "sub eax, %d\n", elem->pos_var_local * 4);
		  fprintf(yyout, "push dword eax\n");
		  break;
		}
	    }
	  else
	    {
	      fprintf(yyout,"push dword _%s\n",$3.lexema);
	    }

	   if (elem->tipo==INT) fprintf(yyout, "call scan_int\n");
	   else fprintf(yyout, "call scan_boolean\n");

	   fprintf(yyout,"add esp,4\n");
	 }
	;

escritura: TOK_printf'('exp')'
	{
	  fprintf(yyout, ";R22:\t\"escritura\" ::= printf(\"exp\")\n");
	  if ($3.tipo==INT)
	    fprintf(yyout, "call print_int\n");
	  else if ($3.tipo==BOOLEAN)
	    fprintf(yyout, "call print_boolean\n");
	  else
	  /*   fprintf(yyout, "call print_int\n"); */
	    {
	      yyerror("Tipo de argumento no aceptable (requiere INT o BOOLEAN)");
	      YYABORT;
	    }
	  fprintf(yyout, "pop ecx\n");
	  fprintf(yyout, "call print_endofline\n");
	};

retorno_funcion: TOK_return exp
	{
	  fprintf(yyout, ";R23:\t\"retorno_funcion\" ::= return \"exp\"\n");
	  // El resultado de exp estará en la cima de la pila
	  // Para retornar, se pone el resultado en eax antes de terminar
	  fprintf(yyout, "pop dword eax\n");
	  fprintf(yyout, "mov esp, ebp\n");
	  fprintf(yyout, "pop ebp\n");
	  fprintf(yyout, "ret\n");
	}
	;

operacion_lista: TOK_insert_front '('exp_identificador',' exp')'
	{ fprintf(yyout, ";R24:\t\"operacion_lista\" ::= insert_front(\"exp_identificador\",\"exp\")\n");
	  if (buscar_simbolo($3.lexema) == NULL) 
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg,"Lista '%s' no declarada", $3.lexema); 
	      flag_error=3;
	      yyerror(msg);
	      YYABORT;
	    }
	  if ($5.tipo != INT) 
	    {
	      flag_error=2;
	      yyerror("Operacion aritmetica con operandos de tipo no permitido");
	      YYABORT;
	    }

	  /*make room*/
	  fprintf(yyout, "push dword 8\n");
	  fprintf(yyout, "call malloc\n");
	  fprintf(yyout, "add esp, 4\n");
	  /*Get args*/
	  fprintf(yyout, "pop ecx\n");
	  fprintf(yyout, "pop ebx\n");

	  /*
	    ebx = list pointer
	    ecx = value to insert
	  */

	  /*errcheck*/
	  fprintf(yyout, "cmp eax, 0\n");
	  fprintf(yyout, "je error_E_M\n");


	  /*connect list to new element*/
	  fprintf(yyout, "mov dword edx, [ebx]\n");
	  fprintf(yyout, "mov dword [eax], edx\n");
	  /*connect new element*/
	  fprintf(yyout, "mov [ebx], eax\n");
	  /*place values into new element*/
	  fprintf(yyout, "mov dword [eax+4], ecx\n");
	  /*update list element count*/
	  fprintf(yyout, "add dword [ebx+4], 1\n");
	}
	| TOK_insert_back'('exp_identificador',' exp')'
	{ fprintf(yyout, ";R24.1:\t\"operacion_lista\" ::= insert_back(\"exp_identificador\",\"exp\")\n");
	  if (buscar_simbolo($3.lexema) == NULL) 
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg,"Lista '%s' no declarada", $3.lexema); 
	      flag_error=3;
	      yyerror(msg);
	      YYABORT;
	    }
	  if ($5.tipo != INT) 
	    {
	      flag_error=2;
	      yyerror("Operacion aritmetica con operandos de tipo no permitido");
	      YYABORT;
	    }
	  /*Get args*/
	  fprintf(yyout, "pop ecx\n");
	  fprintf(yyout, "pop ebx\n");
	  fprintf(yyout, "push ecx\n");
	  fprintf(yyout, "push ebx\n");
	  fprintf(yyout, "call list_last_elem\n");
	  fprintf(yyout, "push eax\n");

	  /*make room*/
	  fprintf(yyout, "push dword 8\n");
	  fprintf(yyout, "call malloc\n");
	  fprintf(yyout, "add esp, 4\n");

	  fprintf(yyout, "pop edx\n");
	  fprintf(yyout, "pop ebx\n");
	  fprintf(yyout, "pop ecx\n");
	  /*
	    edx = pointer to last element
	    ebx = list pointer
	    ecx = value to insert
	  */


	  /*errcheck*/
	  fprintf(yyout, "cmp eax, 0\n");
	  fprintf(yyout, "je error_E_M\n");

	  /*connect new element*/
	  fprintf(yyout, "mov [edx], eax\n");
	  /*place values into new element*/
	  fprintf(yyout, "mov dword [eax], 0\n");
	  fprintf(yyout, "mov [eax+4], ecx\n");
	  /*update list element count*/
	  fprintf(yyout, "add dword [ebx+4], 1\n");

	}
	| TOK_empty'('exp_identificador')'
	{ fprintf(yyout, ";R24.2:\t\"operacion_lista\" ::= empty(\"exp_identificador\")\n");

	  if (buscar_simbolo($3.lexema) == NULL) 
	  {
		  char msg[MAX_CLAVE * 2];
		  sprintf(msg,"Lista '%s' no declarada", $3.lexema); 
	      flag_error=3;
	      yyerror(msg);
	      YYABORT;
	 }

	  /*
	    eax = pointer to last elem
	    ebx = list pointer
	  */
	  fprintf(yyout, "pop ebx\n");

	  fprintf(yyout, "begin_empty%d:\n", etiqueta);
	  fprintf(yyout, "mov ecx, [ebx]\n");
	  fprintf(yyout, "cmp ecx, 0\n");
	  fprintf(yyout, "je end_empty%d\n", etiqueta);
	  fprintf(yyout, "mov edx, [ecx]\n");
	  fprintf(yyout, "mov [ebx], edx\n");

	  fprintf(yyout, "push ecx\n");
	  fprintf(yyout, "call free\n");
	  fprintf(yyout, "add esp, 4\n");
	  fprintf(yyout, "jmp begin_empty%d\n", etiqueta);


	  fprintf(yyout, "end_empty%d:\n", etiqueta);
	  fprintf(yyout, "mov dword [ebx + 4], 0\n");

	  etiqueta++;
    }
	;


info_lista: TOK_extraccion_principio'('exp_identificador')'
	{ fprintf(yyout, ";R25:\t\"info_lista\" ::= extraccion_principio(\"exp_identificador\")\n");
	  if (buscar_simbolo($3.lexema) == NULL) 
	  {
		  char msg[MAX_CLAVE * 2];
		  sprintf(msg,"Lista '%s' no declarada", $3.lexema); 
	      flag_error=3;
	      yyerror(msg);
	      YYABORT;
	 }
	  $$.tipo = INT;

	  /*get all pointers*/
	  /*
	    ebx = list pointer
	    ecx = first element
	    edx = second element
	   */
	  fprintf(yyout, "pop ebx\n");
	  fprintf(yyout, "mov ecx, [ebx]\n");
	  fprintf(yyout, "cmp ecx, 0\n");
	  fprintf(yyout, "je error_E_EX\n");
	  fprintf(yyout, "mov edx, [ecx]\n");

	  /*set list pointer to second element*/
	  fprintf(yyout, "mov dword [ebx], edx\n");
	  /*change list size*/
	  fprintf(yyout, "sub dword [ebx+4], 1\n");

	  /*get data from first element*/
	  fprintf(yyout, "push dword [ecx+4]\n");

	  /*free first element*/
	  fprintf(yyout, "push ecx\n");
	  fprintf(yyout, "call free\n");
	  fprintf(yyout, "pop ecx\n");

	  /*pop data into eax*/
	  fprintf(yyout, "pop eax\n");


    }
	| TOK_extraccion_final'('exp_identificador')'
	{ fprintf(yyout, ";R25.1:\t\"info_lista\" ::= extraccion_final(\"exp_identificador\")\n");
	  $$.tipo = INT;
        /*Lo mismo que antes(copiar codigo)*/
	  if (buscar_simbolo($3.lexema) == NULL) 
	  {
		  char msg[MAX_CLAVE * 2];
		  sprintf(msg,"Lista '%s' no declarada", $3.lexema); 
	      flag_error=3;
	      yyerror(msg);
	      YYABORT;
	 }

	  fprintf(yyout, "cmp dword [ebx], 0\n");
	  fprintf(yyout, "je error_E_EX\n");

	  fprintf(yyout, "call list_penlast_elem\n");
	  fprintf(yyout, "pop ebx\n");

	  fprintf(yyout, "cmp ebx, eax\n");
	  fprintf(yyout, "jne cont%d\n", etiqueta);
	  fprintf(yyout, "cont%d:\n", etiqueta);

	  fprintf(yyout, "mov ecx, [eax]\n");
	  fprintf(yyout, "mov dword [eax], 0\n");
	  fprintf(yyout, "push dword [ecx+4]\n");
	  fprintf(yyout, "push dword [ecx]\n");
	  fprintf(yyout, "call free\n");
	  fprintf(yyout, "pop eax\n");
	  fprintf(yyout, "pop eax\n");

	  fprintf(yyout, "sub dword [ebx+4], 1\n");


	  etiqueta++;

    }
	| TOK_is_empty'('exp_identificador')'
	{ fprintf(yyout, ";R25.2:\t\"info_lista\" ::= is_empty(\"exp_identificador\")\n");
	  $$.tipo = BOOLEAN;
        /*Lo mismo que antes(copiar codigo)*/
	  if (buscar_simbolo($3.lexema) == NULL) 
	  {
		  char msg[MAX_CLAVE * 2];
		  sprintf(msg,"Lista '%s' no declarada", $3.lexema); 
	      flag_error=3;
	      yyerror(msg);
	      YYABORT;
	 }
	  fprintf(yyout, "pop ebx\n");
	  fprintf(yyout, "mov eax, [ebx+4]\n");

	  fprintf(yyout,"or eax , eax \n");
	  fprintf(yyout,"jz near negar_falso%d \n",etiqueta);
	  fprintf(yyout,"mov dword eax,0 \n");
	  fprintf(yyout,"jmp near fin_negacion%d \n",etiqueta);
	  fprintf(yyout,"negar_falso%d: mov dword eax,1 \n",etiqueta);
	  fprintf(yyout,"fin_negacion%d: \n",etiqueta);
	  etiqueta++;


	}
	| TOK_size_of'('exp_identificador')'
	{ fprintf(yyout, ";R25.3:\t\"info_lista\" ::= extraccion_principio(\"exp_identificador\")\n");
	  $$.tipo = INT;

	  if (buscar_simbolo($3.lexema) == NULL) 
	  {
		  char msg[MAX_CLAVE * 2];
		  sprintf(msg,"Lista '%s' no declarada", $3.lexema); 
	      flag_error=3;
	      yyerror(msg);
	      YYABORT;
	 }
	  fprintf(yyout, "pop ebx\n");
	  fprintf(yyout, "mov eax, [ebx+4]\n");
    }
	;

exp: exp '+' exp
	{
	  fprintf(yyout, ";R26:\t\"exp\" ::= \"exp\" + \"exp\"\n");

	  if (($1.tipo != INT) || ($3.tipo != INT))
	    {
	      flag_error=2;
	      yyerror("Operacion aritmetica con operandos de tipo no permitido");
	      YYABORT;
	    }

	  $$.tipo = INT;
	  fprintf(yyout,"pop dword edx \n");
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"add eax, edx \n");
	  fprintf(yyout,"push dword eax \n");
	}
	| exp '-' exp
	{
	  fprintf(yyout, ";R26.1:\t\"exp\" ::= \"exp\" - \"exp\"\n");
	  if (($1.tipo != INT) || ($3.tipo != INT))
	    {
	      flag_error=2;
	      yyerror("Operacion aritmetica con operandos de tipo no permitido");
	      YYABORT;
	    }
	  
	  $$.tipo = INT;
	  fprintf(yyout,"pop dword edx \n");
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"sub eax, edx \n");
	  fprintf(yyout,"push dword eax \n");
	}
	/*| exp '%' exp
	{ fprintf(yyout, ";R26.2:\t\"exp\" ::= \"exp\" % \"exp\"\n");}*/
	| exp '/' exp
	{
	  fprintf(yyout, ";R26.3:\t\"exp\" ::= \"exp\" / \"exp\"\n");
	  if (($1.tipo != INT) || ($3.tipo != INT))
	    {
	      flag_error=2;
	      yyerror("Operacion aritmetica con operandos de tipo no permitido");
	      YYABORT;
	    }

	  $$.tipo = INT;

	  fprintf(yyout,"pop dword ecx\n");
	  fprintf(yyout,"pop dword eax\n");
	  fprintf(yyout,"cmp ecx,0 \n"); 
	  fprintf(yyout,"je near error_E\n");
	  fprintf(yyout,"cdq\n");
	  fprintf(yyout,"idiv ecx\n");
	  fprintf(yyout,"push dword eax\n");
	}
	| exp '*' exp
	{
	  fprintf(yyout, ";R26.4:\t\"exp\" ::= \"exp\" * \"exp\"\n");
	  if (($1.tipo != INT) || ($3.tipo != INT))
	    {
	      flag_error=2;
	      yyerror("Operacion aritmetica con operandos de tipo no permitido");
	      YYABORT;
	    }
	  
	  $$.tipo = INT;
	  fprintf(yyout, "pop dword edx \n");
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"imul edx \n");
	  fprintf(yyout,"push dword eax \n");
	}
	| exp '^' exp
	{
	  fprintf(yyout, ";R26.4:\t\"exp\" ::= \"exp\" ^ \"exp\"\n");
	  if (($1.tipo != INT) || ($3.tipo != INT))
	    {
	      flag_error=2;
	      yyerror("Operacion aritmetica con operandos de tipo no permitido");
	      YYABORT;
	    }

	  $$.tipo = INT;

	  fprintf(yyout, "pop dword ebx \n");
	  fprintf(yyout, "pop dword ecx \n");

	  fprintf(yyout, "mov dword eax, 1 \n");
	  fprintf(yyout, "cmp dword ebx, 0 \n");
	  fprintf(yyout, "jge near begin_%d\n", etiqueta);
	  fprintf(yyout, "push dword 0 \n");
	  fprintf(yyout, "jmp near end%d \n", etiqueta);

	  fprintf(yyout, "begin_%d: \n", etiqueta);
	  fprintf(yyout, "cmp dword ebx, 1 \n");
	  fprintf(yyout, "jl near last%d \n", etiqueta);

	  fprintf(yyout, "imul ecx \n");
	  fprintf(yyout, "dec ebx \n");
	  fprintf(yyout, "jmp begin_%d \n", etiqueta);

	  fprintf(yyout, "last%d: \n", etiqueta);
	  fprintf(yyout, "push dword eax \n");
	  fprintf(yyout, "end%d: \n", etiqueta);
	  etiqueta++;

	}
        | exp_personalizado
	| '-'exp 
	{
	  fprintf(yyout, ";R26.5:\t\"exp\" ::= -\"exp\"\n");
	  if ($2.tipo != INT)
	    {
	      flag_error=2;
	      yyerror("Operacion aritmetica con operandos de tipo no permitido");
	      YYABORT;
	    }
	  
	  $$.tipo = INT;
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"neg eax \n");
	  fprintf(yyout,"push dword eax \n");
	}
	| exp TOK_and exp
	{
	  fprintf(yyout, ";R26.6:\t\"exp\" ::= \"exp\" && \"exp\"\n");
	  if (($1.tipo != BOOLEAN) || ($3.tipo != BOOLEAN))
	    {
	      flag_error=2;
	      yyerror("Operacion logica con operandos de tipo no permitido");
	      YYABORT;
	    }
	  
	  $$.tipo = BOOLEAN;
	  fprintf(yyout,"pop dword edx \n");
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"and eax , edx \n");
	  fprintf(yyout,"push dword eax \n");
	}
	| exp TOK_or exp
	{
	  fprintf(yyout, ";R26.7:\t\"exp\" ::= \"exp\" || \"exp\"\n");
	  if (($1.tipo != BOOLEAN) || ($3.tipo != BOOLEAN))
	    {
	      flag_error=2;
	      yyerror("Operacion logica con operandos de tipo no permitido");
	      YYABORT;
	    }

	 $$.tipo = BOOLEAN;
	 fprintf(yyout,"pop dword edx \n");
	 fprintf(yyout,"pop dword eax \n");
	 fprintf(yyout,"or eax , edx \n");
	 fprintf(yyout,"push dword eax \n"); 
	}
	| '!'exp
	{
	  fprintf(yyout, ";R26.8:\t\"exp\" ::= !\"exp\"\n");
	  if ($2.tipo != BOOLEAN)
	    {
	      flag_error=2;
	      yyerror("Operacion logica con operandos de tipo no permitido");
	      YYABORT;
	    }
	  
	  $$.tipo = BOOLEAN;
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"or eax , eax \n");
	  fprintf(yyout,"jz near negar_falso%d \n",etiqueta);
	  fprintf(yyout,"mov dword eax,0 \n");
	  fprintf(yyout,"jmp near fin_negacion%d \n",etiqueta);
	  fprintf(yyout,"negar_falso%d: mov dword eax,1 \n",etiqueta);
	  fprintf(yyout,"fin_negacion%d: push dword eax \n",etiqueta);
	  etiqueta++;
	}
	| exp_identificador
	{
	  if (!(($1.tipo == INT) || ($1.tipo == BOOLEAN)))
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg, "Intento equivocado de acceso a una variable no escalar.(%s)", $1.lexema);
	      flag_error = SEMANTICO;
	      yyerror(msg);
	      YYABORT;
	    }
	}
	| constante
	{
	  fprintf(yyout, ";R26.10:\t\"exp\" ::= \"constante\"\n");
	  $$.tipo = $1.tipo;
	  $$.valor_entero = $1.valor_entero;
	  fprintf(yyout, "push %d\n", $$.valor_entero);
	}
	| '('exp')'
	{
	  fprintf(yyout, ";R26.11:\t\"exp\" ::= (\"exp\")\n");
	  $$.tipo = $2.tipo;
	}
	| '('comparacion')'
	{
	  fprintf(yyout, ";R26.12:\t\"exp\" ::= (\"comparacion\")\n");
	  if ($2.tipo != BOOLEAN)
	    {
	      flag_error=2;
	      yyerror("Comparacion con operandos de tipo no permitido");
	      YYABORT;
	    }
	  
	  $$.tipo = BOOLEAN;
	}
	| identificador'('lista_exp')'
	{
	  elem* this;
	  fprintf(yyout, ";R26.13:\t\"exp\" ::= \"identificador\" (\"lista_exp\")\n");
	  this = buscar_th(global, $1.lexema);
	  if (this == NULL)
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg, "Intento de acceso a una variable no declarada (%s)", $1.lexema);
	      flag_error=SEMANTICO;
	      yyerror(msg);
	      YYABORT;
	    }
	  if (this->categoria != FUNCION)
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg, "Intento de acceso a una variable como si fuera una funcion.(%s)", $1.lexema);
	      flag_error = SEMANTICO;
	      yyerror(msg);
	      YYABORT;
	    }
	  if (this->num_parametros != $3.valor_entero)
	    {
	      flag_error = SEMANTICO;
	      yyerror("Numero invalido de parametros en llamada a funcion");
	      YYABORT;
	    }
	  $$.tipo = this->tipo;

	  fprintf(yyout, "call _%s\n", $1.lexema);
	  fprintf(yyout, "add esp, %d\n", $3.valor_entero * 4);
	  fprintf(yyout, "push dword eax\n");
	}
	| info_lista
	{
	  fprintf(yyout, ";R26.14:\t\"exp\" ::= \"info_lista\"\n");
	  $$.tipo = $1.tipo;
	  fprintf(yyout, "push eax\n");

	}
	;

	
identificador : TOK_ID
	{ fprintf(yyout, ";R27:\t\"identificador\" ::= ID\n");
	  strcpy($$.lexema, $1.lexema);
	}
	;

exp_identificador : identificador
	{
	  elem* this;
	  int loc;
	  fprintf(yyout, ";R26.9:\t\"exp\" ::= \"identificador\"\n");
	  strcpy($$.lexema, $1.lexema);
	  this = buscar_simbolo_gl($1.lexema, &loc);
	  if (this == NULL)
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg, "Intento de acceso a una variable no declarada (%s)", $1.lexema);
	      flag_error=SEMANTICO;
	      yyerror(msg);
	      YYABORT;
	    }
	  if (this->categoria == FUNCION)
	    {
	      char msg[MAX_CLAVE * 2];
	      sprintf(msg, "Intento equivocado de acceso a una funcion como si fuera una variable.(%s)", $1.lexema);
	      flag_error = SEMANTICO;
	      yyerror(msg);
	      YYABORT;
	    }
	  $$.tipo = this->tipo;

	  if (loc == LOCAL)
	    {
	      switch (this->categoria)
		{
		case PARAMETRO:
		  fprintf(yyout, "push dword [ebp+%d]\n", (1 + (func_local->num_parametros - (this->pos_parametro))) * 4);
		  break;
		case VARIABLE:
		  fprintf(yyout, "push dword [ebp-%d]\n", this->pos_var_local * 4);
		  break;
		}
	    }
	  else
	    {
	      fprintf(yyout, "push dword [_%s]\n", this->clave);
	    }

	}

lista_exp : exp resto_exp 
	{
	  fprintf(yyout, ";R28:\t\"lista_exp\" ::= \"exp\" \"resto_exp\"\n");
	  $$.valor_entero = 1 + $2.valor_entero;
	}
	| 
	{ fprintf(yyout, ";R28.1:\t\"lista_exp\" ::= \n");
	  $$.valor_entero = 0;}
	;

resto_exp : ',' exp resto_exp 
	{fprintf(yyout, ";R29:\t\"resto_exp\" ::= ,\"exp\" \"resto_exp\"\n");
	  $$.valor_entero = 1 + $3.valor_entero;
	}
	| 
	{fprintf(yyout, ";R29.1:\t\"resto_exp\" ::= \n");
	  $$.valor_entero = 0;}
	;


    /*No se puede comparar expresiones lógicas*/    
comparacion : exp TOK_igual_a exp 
	{fprintf(yyout, ";R30:\t\"comparacion\" ::= \"exp\" == \"exp\"\n");
        if (($1.tipo == INT) && ($3.tipo == INT))
	  {
	    $$.tipo = BOOLEAN;
	    fprintf(yyout, "pop dword edx \n");
	    fprintf(yyout,"pop dword eax \n");
	    fprintf(yyout,"cmp eax, edx \n");
	    fprintf(yyout,"je near verdad%d \n", etiqueta);
	    fprintf(yyout,"mov dword eax, 0 \n");
	    fprintf(yyout,"jmp near fincmp%d \n", etiqueta);
	    fprintf(yyout,"verdad%d: mov dword eax, 1 \n", etiqueta);
	    fprintf(yyout,"fincmp%d: push eax \n", etiqueta);
	    etiqueta++;
	  }
	else
	  {
	    flag_error=2;
	    yyerror("Comparacion con operandos de tipo no permitido");
	    YYABORT;
	  }
    }
	| exp TOK_diferente_de exp 
	{fprintf(yyout, ";R30.1:\t\"comparacion\" ::= \"exp\" != \"exp\"\n");
        if(($1.tipo == INT) && ($3.tipo == INT)){
          $$.tipo= BOOLEAN;
	  fprintf(yyout, "pop dword edx \n");
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"cmp eax, edx \n");
	  fprintf(yyout,"jne near verdad%d \n",etiqueta);
	  fprintf(yyout,"mov dword eax, 0 \n");
	  fprintf(yyout,"jmp near fincmp%d \n",etiqueta);
	  fprintf(yyout,"verdad%d: mov dword eax, 1 \n",etiqueta);
	  fprintf(yyout,"fincmp%d: push eax \n",etiqueta);
	  etiqueta++;
        } else {
	  flag_error=2;
	  yyerror("Comparacion con operandos de tipo no permitido");
	  YYABORT;
	}
    }
	| exp TOK_menor_igual exp 
	{fprintf(yyout, ";R30.2:\t\"comparacion\" ::= \"exp\" {= \"exp\"\n");
        if(($1.tipo==INT) && ($3.tipo==INT)){
          $$.tipo= BOOLEAN;
	  fprintf(yyout, "pop dword edx \n");
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"cmp eax, edx \n");
	  fprintf(yyout,"jle near verdad%d \n",etiqueta);
	  fprintf(yyout,"mov dword eax, 0 \n");
	  fprintf(yyout,"jmp near fincmp%d \n",etiqueta);
	  fprintf(yyout,"verdad%d: mov dword eax, 1 \n",etiqueta);
	  fprintf(yyout,"fincmp%d: push eax \n",etiqueta);
	  etiqueta++;
        } else {
	  flag_error=2;
	  yyerror("Comparacion con operandos de tipo no permitido");
	  YYABORT;
	}
    }
	| exp TOK_mayor_igual exp 
	{fprintf(yyout, ";R30.3:\t\"comparacion\" ::= \"exp\" }= \"exp\"\n");
        if(($1.tipo==INT) && ($3.tipo==INT)){
          $$.tipo= BOOLEAN;
	  fprintf(yyout, "pop dword edx \n");
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"cmp eax, edx \n");
	  fprintf(yyout,"jge near verdad%d \n",etiqueta);
	  fprintf(yyout,"mov dword eax, 0 \n");
	  fprintf(yyout,"jmp near fincmp%d \n",etiqueta);
	  fprintf(yyout,"verdad%d: mov dword eax, 1 \n",etiqueta);
	  fprintf(yyout,"fincmp%d: push eax \n",etiqueta);
	  etiqueta++;
	} else {
	  flag_error=2;
	  yyerror("Comparacion con operandos de tipo no permitido");
	  YYABORT;
	}
    }
	| exp '{' exp 
	{fprintf(yyout, ";R30.4:\t\"comparacion\" ::= \"exp\" { \"exp\"\n");
        if(($1.tipo==INT) && ($3.tipo==INT)){
	  $$.tipo = BOOLEAN;
	  fprintf(yyout, "pop dword edx \n");
	  fprintf(yyout,"pop dword eax \n");
	  fprintf(yyout,"cmp eax, edx \n");
	  fprintf(yyout,"jl near verdad%d \n",etiqueta);
	  fprintf(yyout,"mov dword eax, 0 \n");
	  fprintf(yyout,"jmp near fincmp%d \n",etiqueta);
	  fprintf(yyout,"verdad%d: mov dword eax, 1 \n",etiqueta);
	  fprintf(yyout,"fincmp%d: push eax \n",etiqueta);
	  etiqueta++;
        } else {
	  flag_error=2;
	  yyerror("Comparacion con operandos de tipo no permitido");
	  YYABORT;
	}
    }
	| exp '}' exp 
	{
	  fprintf(yyout, ";R30.5:\t\"comparacion\" ::= \"exp\" } \"exp\"\n");
	  if(($1.tipo==INT) && ($3.tipo==INT)){
	    $$.tipo = BOOLEAN;
	    fprintf(yyout, "pop dword edx \n");
	    fprintf(yyout,"pop dword eax \n");
	    fprintf(yyout,"cmp eax, edx \n");
	    fprintf(yyout,"jg near verdad%d \n",etiqueta);
	    fprintf(yyout,"mov dword eax, 0 \n");
	    fprintf(yyout,"jmp near fincmp%d \n",etiqueta);
	    fprintf(yyout,"verdad%d: mov dword eax, 1 \n",etiqueta);
	    fprintf(yyout,"fincmp%d: push eax \n",etiqueta);
	    etiqueta++;
	  } else {
	    flag_error=2;
	    yyerror("Comparacion con operandos de tipo no permitido");
	    YYABORT;
	  }
	}
	;

constante : constante_logica 
	{fprintf(yyout, ";R31:\t\"constante\" ::= \"constante_logica\"\n");
        $$.valor_entero= $1.valor_entero;
        $$.tipo=BOOLEAN;
    }
	| constante_entera 
	{fprintf(yyout, ";R31.1:\t\"constante\" ::= \"constante_entera\"\n");
        $$.valor_entero= $1.valor_entero;
        $$.tipo=INT;
    }
	;
constante_logica : TOK_true 
	{fprintf(yyout, ";R32:\t\"constante_logica\" ::= true\n");
        $$.valor_entero= $1.valor_entero;
    }
	| TOK_false 
	{fprintf(yyout, ";R32.1:\t\"constante_logica\" ::= false\n");
        $$.valor_entero= $1.valor_entero;
    }
	;
constante_entera : TOK_constante 
	{
	  fprintf(yyout, ";R33:\t\"constante_entera\" ::= unaconstante\n");
	  $$.valor_entero= $1.valor_entero;
	}
	;
%%
