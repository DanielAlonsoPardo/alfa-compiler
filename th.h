#ifndef _TH_H_
#define _TH_H_

#include <limits.h>

#define DEFAULT_TH_TAM 100

#define NOT_INIT -1
//categoria
#define VARIABLE 1
#define PARAMETRO 2
#define FUNCION 3
//tipo
#define BOOLEAN 1
#define INT 2
//clase
#define ESCALAR 0
#define LISTA 3

#define MAX_CLAVE 100

#define ERR -1
#define OK 1

typedef struct elem
{
  char clave[MAX_CLAVE + 1]; //Identificador
  int categoria;         //Funcion,parametro,variable
  int tipo;              //boolean,int
  int clase;             //escalar,lista
  int num_parametros;    //si es funcion,num parametros
  int pos_parametro;     //si es parametro, posicion
  int num_var_locales;   //si es funcion, num variables locales
  int pos_var_local;     //si es var local, posicion
  int valor_init;        //valor inicial, por defecto 0
  struct elem *siguiente;
}elem;

typedef struct th
{
  elem *tabla;
  char *nombre;
  int tam;
}th;

th* crear_th (int tam, char* nombre);
elem* crea_elem(char *clave, int categoria, int tipo, int clase, int num_parametros, int pos_parametro, int num_var_locales, int pos_var_local);
int libera_th (th** tabla);
int funcion_H (char *clave, int tam);
elem* buscar_th (th* tabla, char* clave);
int insertar_th (th* tabla, elem* obj);

#endif
