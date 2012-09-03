--"IMPORTS"
with Ada.Text_IO;
with Ada.Integer_Text_IO;
with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Directories; use Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Containers.Generic_Array_Sort;
-- FIM "IMPORTS"

procedure Sstat is
	--RENAMES
	package IO renames Ada.Text_IO;
	package CL renames Ada.Command_Line;
	package EX renames Ada.Exceptions;
	package DIR renames Ada.Directories;
	package SU renames Ada.Strings.Unbounded;
	package ST renames Ada.Streams.Stream_IO;
	package IIO renames Ada.Integer_Text_IO;
	package SF renames Ada.Strings.Fixed;
	--FIM RENAMES
	
	--VARIAVEIS
	Last: Natural; --usada em "get_line"
	Indice_Inserir: Integer := 1; --usada para em qual posicao do array inserir e ateh onde imprimir
	Linha: String(1..1024); --usada para pegar a linha do arquivo
	Qtde_Linhas: Integer := 0; --usada para contar as linhas do arquivo
	A_File: IO.File_Type; --usada para abrir arquivo
	Extensao: SU.Unbounded_String; --extensao do arquivo sendo processado
	--FIM VARIAVEIS
	
	--DECLARACOES
	--tipo de dado proprio
	type TResultado is
	record
		Numero_Linhas : Integer;
		Extensao : SU.Unbounded_String;
	end record;
	--lista que contem todos os resultados
	Resultados: array (1..1024) of TResultado;
	
	--exemplo de uso de subprograma
	function ehDiretorio(string: SU.Unbounded_String) return Boolean is
		use DIR;
    begin
        return DIR.Kind(SU.To_String(string)) = DIR.Directory;
    end ehDiretorio;
	
	procedure somaLinhas(extensao: SU.Unbounded_String; linhas:Integer) is
		a_resultado: TResultado;
		a_existe: Boolean := false;
	begin
		--percorre o array
		for I in Resultados'Range loop
			--se encontrar a extensao, soma as linhas e sai
			if SU.To_String(Resultados(I).extensao) = SU.To_String(extensao) then
				Resultados(I).numero_linhas := Resultados(I).numero_linhas + linhas;
				a_existe := true;
				exit when true;
			end if;
		end loop;
		--se nao encontrar, adiciona no array
		if not a_existe then
			a_resultado.extensao := extensao;
			a_resultado.numero_linhas := linhas;
			Resultados(indice_inserir) := a_resultado;
			indice_inserir := indice_inserir + 1;
		end if;
	end;
	
	--funcao que compara os dois registros
	function aMenorB(a,b: TResultado) return Boolean is
	begin
		if (a.numero_linhas = b.numero_linhas) then
			return SU.To_String(a.extensao) > SU.To_String(b.extensao);
		end if;
		return a.numero_linhas < b.numero_linhas;
	end;
	
	procedure imprimeResultados is
		a_total: Integer := 0;
		Value : TResultado;
		J : Natural;
		maior_tamanho: Integer := 0;
	begin
		if (indice_inserir > 1) then --imprimir somente se tiver resultados
			--ORDENAR
			for I in Resultados'First + 1 .. indice_inserir -1 loop
				Value := Resultados(I);
				J := I - 1;
				while J >= Resultados'First and then aMenorB(Resultados(J), Value) loop
					Resultados(J + 1) := Resultados(J);
					J := J - 1;
				end loop;
				Resultados(J + 1) := Value;
			end loop;
		
			--encontrar maior numero para alinhar
			for K in Resultados'Range loop
				a_total := a_total + Resultados(K).numero_linhas;
				exit when K = indice_inserir - 1;
			end loop;
			maior_tamanho := SU.Length(SU.To_Unbounded_String(Integer'Image(a_total))) - 1;
			
			--imprimir resultados
			for K in Resultados'Range loop
				IIO.Put(Resultados(K).numero_linhas, maior_tamanho);
				IO.Put(" " & SU.To_String(Resultados(K).extensao));
				IO.New_Line;
				exit when K = indice_inserir - 1;
			end loop;
		end if;
		IIO.Put(a_total, 0);
		IO.Put(" total");
	end;
	
	function contaLinhas(arquivo: String) return Integer is
		a_qtde_linhas: Integer := 0;
	begin
		IO.Open(File => A_File, Name => arquivo, Mode => IO.In_File);
		while not IO.End_Of_File(A_File) loop
			a_qtde_linhas := a_qtde_linhas + 1;
			--sem essa linha entra em loop infinito
			IO.Get_Line(File => A_File, Item => linha, Last => Last);
		end loop;
		IO.Close(A_File);
		return a_qtde_linhas;
	end;
	
	procedure processaArquivo(arquivo: String) is
		extensao: SU.Unbounded_String;
	begin
		extensao := SU.To_Unbounded_String(DIR.Extension(arquivo));
		if SU.To_String(extensao) /= "" then
			qtde_linhas := contaLinhas(arquivo);
			somaLinhas(extensao, qtde_linhas);
		end if;
	end;
	
	procedure processaDiretorio(diretorio: String) is
		Filter : constant DIR.Filter_Type := (DIR.Ordinary_File => True, DIR.Special_File => False, DIR.Directory => True);
		A_Search: DIR.Search_Type; --usada para percorrer diretorios
		Search_Item: DIR.Directory_Entry_Type; --usada para percorrer diretorios
	begin
		DIR.Start_Search(Search => A_Search, Directory => diretorio, Pattern => "", Filter => Filter);
		while DIR.More_Entries(Search => A_Search) loop
			DIR.Get_Next_Entry(Search => A_Search, Directory_Entry => Search_Item);
			if DIR.Kind(Directory_Entry => Search_Item) = DIR.Directory and
					DIR.Simple_Name(Directory_Entry => Search_Item) /= ".." and
					SF.Index(DIR.Full_Name(Directory_Entry => Search_Item), ".") = 0  then
				processaDiretorio(DIR.Full_Name(Directory_Entry => Search_Item));
			end if;
			
			processaArquivo(DIR.Full_Name(Directory_Entry => Search_Item));
		end loop;
		DIR.End_Search(Search => A_Search);
	end;
	--FIM DECLARACOES
	
--INICIO
begin
	--verifica se algum argumento foi passado
	if CL.Argument_Count = 0 then EX.Raise_Exception(DIR.Name_Error'Identity, "nenhum argumento"); end if;
	--percorre todos os argumentos
	for Arg in 1..CL.Argument_Count loop
		--verifica se argumento eh valido
		if not DIR.Exists(CL.Argument(Arg)) then EX.Raise_Exception(DIR.Name_Error'Identity, CL.Argument(Arg) & " nao existe"); end if;

		if (ehDiretorio(SU.To_Unbounded_String(CL.Argument(Arg)))) then
			if (SF.Index(CL.Argument(Arg), "/") = 0) then
				processaDiretorio(DIR.Current_Directory);
			else
				processaDiretorio(CL.Argument(Arg));
			end if;
		else
			processaArquivo(CL.Argument(Arg));
		end if;
	end loop;
	
	imprimeResultados;
exception
	when Error: others =>
		IO.Put_Line(EX.Exception_Information(Error));
end Sstat;
