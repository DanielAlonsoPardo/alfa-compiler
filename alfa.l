%{
#include "alfa.h"
#include "parser.h"
#include <stdio.h>

#define TOK_ERR -1
extern int numero_fila;
extern int numero_col;
extern int flag_error;
extern FILE *yyout; 
extern char morf_err[50];

%}

%option noyywrap

DIGITO	[0-9]
LETRA	[a-zA-Z]
BLANCO	[ \t]
RET	\n
COMENT 	"//".*\n|"<!--"+(.|\n)*+"-->"
ID	{LETRA}({LETRA}|{DIGITO}|"_")*
ENT	{DIGITO}+
ERROR	({DIGITO}|{LETRA})+|.
	
%%

"<"lista				{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_abrir_lista;}
"<"programa 			{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_abrir_programa;}
"<"variables 			{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_abrir_variables;}
"<"funciones 			{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_abrir_funciones;}
"<"main					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_abrir_main;}
"<"args					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_abrir_args;}
"<"if					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_abrir_if;}
"<"else					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_abrir_else;}
"<"repeat				{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_abrir_repeat;}
int                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_var_ent;}
logico                  {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_var_logica;}
lista                   {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_lista;}
programa                {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_programa;}
variables 				{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_variables;}
funciones 				{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_funciones;}
main					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_main;}
args					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_args;}
if                      {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_if;}
else					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_else;}
repeat					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_repeat;}
true					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); yylval.atributos.valor_entero=1; return TOK_true;}
false					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); yylval.atributos.valor_entero=0; return TOK_false;}
"+"                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"-"                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"/"                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"*"                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"^"                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"&&" 					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_and;}
"||" 					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_or;}
"!" 					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"(" 					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
")" 					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"{" 					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"}" 					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"="                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"</"					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_cerrar_tag;}
"=="					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_igual_a;}
"!="					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_diferente_de;}
"{="					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_menor_igual;}
"}="					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_mayor_igual;}
";"                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"'"                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"<"                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
">"                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
"%"                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
","                     {numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return yytext[0];}
until					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_until;}
condition				{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_condition;}
name 					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_name;}
scanf					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_scanf;}
printf					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_printf;}
clonar				{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_personalizado;}
en				{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_en;}
exp_personalizado				{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_exp_personalizado;}
return					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_return;}
insert_front			{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_insert_front;}
insert_back				{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_insert_back;}
empty					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_empty;}
extraccion_principio	{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_extraccion_principio;}
extraccion_final		{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_extraccion_final;}
is_empty				{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_is_empty;}
size_of					{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); return TOK_size_of;}



{ID}    {numero_col += yyleng;
         if (yyleng >= MAX_ID) {
           flag_error = 1;
           sprintf(morf_err, "IDENTIFICADOR DEMASIADO LARGO (%s)", yytext);
           return TOK_ERR;
	 } else {
	   fprintf(yyout,";D:\t%s\n", yytext);
	   strcpy(yylval.atributos.lexema, yytext);
	   return TOK_ID;
	 };
        }
{ENT}		{numero_col += yyleng; fprintf(yyout,";D:\t%s\n", yytext); yylval.atributos.valor_entero=atoi(yytext); return TOK_constante;}
{COMENT}	{numero_fila ++; numero_col = 1;}
{BLANCO}+	{numero_col += yyleng;}
{RET}		{numero_fila ++; numero_col = 1;}
{ERROR}		{numero_col += yyleng; flag_error = 1; 
           sprintf(morf_err, "CARACTER NO PERMITIDO (%s)", yytext);
           return TOK_ERR;}

%%
