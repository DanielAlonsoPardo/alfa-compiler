#include "th.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

th* crear_th (int tam, char* nombre){
    int i;
    th* tabla;

    if (tam < 0){
        printf("Tamano incorrecto\n");
        return NULL;
    }

    tabla = (th *)malloc(sizeof(th)); 

    if (!tabla){
        printf("Error al crear la tabla hash\n");
        return NULL;
    }

    tabla->tam = tam;
    tabla->nombre = (char*)malloc(sizeof(char) * strlen(nombre) + 1);
    strcpy(tabla->nombre, nombre);
    tabla->tabla = (elem*)malloc(tam * sizeof(elem));

  for (i = 0; i < tam; i++)
    {
      tabla->tabla[i].clave[0] = '\0';
      tabla->tabla[i].categoria = -1;
      tabla->tabla[i].tipo = -1;
      tabla->tabla[i].clase = -1;
      tabla->tabla[i].num_parametros = -1;
      tabla->tabla[i].pos_parametro = -1;
      tabla->tabla[i].num_var_locales = -1;
      tabla->tabla[i].pos_var_local = -1;
      tabla->tabla[i].siguiente = NULL;
    }

  if (!tabla->tabla)
    {
      printf("Error al crear la tabla de elementos\n");
      free(tabla); 
      return NULL;
    }

  return tabla;	
}

elem* crea_elem(char *clave, int categoria, int tipo, int clase, 
                int num_parametros, int pos_parametro, int num_var_locales, int pos_var_local){
    elem* elemento;
    
    elemento = (elem *) malloc(sizeof(elem));
    strcpy(elemento->clave, clave);
    elemento->categoria = categoria; 
    elemento->tipo = tipo; 
    elemento->clase = clase; 
    elemento->num_parametros = num_parametros; 
    elemento->pos_parametro = pos_parametro; 
    elemento->num_var_locales = num_var_locales;
    elemento->pos_var_local = pos_var_local;
    elemento->siguiente = NULL;
    
    return elemento;
}
	
int libera_th(th **tabla)
{
  elem *aux;
  int i;
	
  if (!*tabla)
    {
      printf("libera_th: La tabla no existe\n");
      return ERR;
    }

  for(i = 0; i < (*tabla)->tam; i++)
    {
      while((*tabla)->tabla[i].siguiente)
	{
	  aux = (*tabla)->tabla[i].siguiente;
	  (*tabla)->tabla[i].siguiente = (*tabla)->tabla[i].siguiente->siguiente;
	  free(aux);
	}
    }
  free((*tabla)->tabla);
  free((*tabla)->nombre);
  free((*tabla));

  return OK;
}

int funcion_H (char *clave, int tam)
{
  int c, i;
  int resultado = 0;

  if (!clave)
    {
      printf("funcion_H: Clave erronea\n");
      return ERR;
    }

  c = strlen(clave);
  for (i = 0; i < c; i++)
    resultado = (resultado * 2) + ((int) clave[i]);

  resultado = resultado % tam;

  return resultado;
}

elem *buscar_th (th* tabla, char* clave)
{
  elem *aux;
  int pos = -1;

  if (!tabla)
    {
      printf("buscar_th: tabla inexistente\n");
      return NULL;
    }
	
  if (!clave)
    {
      printf("buscar_th: clave erronea\n");
      return NULL;
    }
	
  pos = funcion_H(clave, tabla->tam);
	
  if (pos < 0)
    {
      printf("buscar_th: La funcion_H no devolvio un valor correcto\n");
      return NULL;
    }

  if (tabla->tabla[pos].categoria == NOT_INIT)
    return NULL;
    
  if (strcmp(tabla->tabla[pos].clave, clave) == 0)
    return &(tabla->tabla[pos]);

  aux = tabla->tabla[pos].siguiente;
  while(aux)
    {
      if (strcmp(aux->clave, clave) == 0)
	return aux;
      aux= aux->siguiente;
    }
	
  return NULL;
}

int insertar_th (th* tabla, elem* obj)
{
  int pos=-1;
  elem* aux= NULL;

  if (!tabla)
    {
      printf("insertar_th: tabla inexistente\n");
      return ERR; 	
    }
	
  if (!obj)
    {
      printf("insertar_th: No hay elemento\n");
      return ERR;
    }

  pos = funcion_H(obj->clave, tabla->tam);
  /*printf("pos=%d\t",pos);
  printf("%s\n", obj->clave);*/

  if (pos < 0)
    {
      printf("insertar_th: La funcion_H no devolvio un valor correcto\n");
      return ERR;
    }

  if (buscar_th(tabla,obj->clave))
    {
      printf("insertar_th: Ya existe el elemento en la tabla\n");
      return ERR;
    }
  aux = &(tabla->tabla[pos]);
  if (aux->tipo == -1)
    memcpy(&tabla->tabla[pos], obj, sizeof(elem));
  else
    {
      while ((aux->siguiente) != NULL)
	aux = aux->siguiente;
      aux->siguiente = (elem*)malloc(sizeof(elem));
      memcpy(aux->siguiente, obj, sizeof(elem));
    }
  return OK;		
}
