
:- module(integracion, [
    grafica_pesajes/2
]).

:- use_module('hechos.pl').
:- use_module(library(janus)).
:- use_module(library(lists)).

% Encontrar graficas.py en esta carpeta.
:- prolog_load_context(directory, Dir),
   py_add_lib_dir(Dir, first).

grafica_pesajes(Animal, SVG) :-
    registro(Animal, _, _),

    % Obtener los pesajes de Prolog.
    findall(
        Dia-Peso,
        lectura(Animal, peso_kg, Peso, Dia),
        Pesajes
    ),

    Pesajes \== [],

    % Ordenar cronologicamente.
    keysort(Pesajes, Ordenados),

    % Convertir los pares en listas Python.
    findall(
        [Dia, Peso],
        member(Dia-Peso, Ordenados),
        Datos
    ),

    % Python genera la imagen.
    py_call(
        graficas:svg_pesajes(Animal, Datos),
        SVG
    ).
