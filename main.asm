; ----------------------------
; Simulador de movimiento de bloques y particionamiento en memoria caché.
; Narváez Brayan - 24905388
; Viernes 27-01-2017
; ASSEMBLYx86 MASM32 + IRVINE32 (I/O)
; ----------------------------
.386
INCLUDE Irvine32.inc
BufSize = 80

; ----------------------------
; Sección de declaración
; ----------------------------
.data
	; ----------------------------
	; Variables de uso global
	; ----------------------------
	$br_str BYTE " ",0dh,0ah,0 
	$menuStr BYTE "SIMULADOR DE CACHE",
	0dh, 0ah, 0dh, 0ah,
	"1- Particionamiento de bits de direcciones", 0dh, 0ah,
	"2- Reemplazo de Bloques", 0dh, 0ah,
	"3- Salir", 0dh, 0ah,
	"Opcion: ", 0
	$menuRegreso BYTE "Continuar en el programa? 1(Si) / 2(No): ", 0
	$sTAG BYTE "TAG: ", 0
	$sSIC BYTE "SIC: ", 0
	$sBIC BYTE "BIC: ", 0
	$sWIB BYTE "WIB: ", 0
	$sMod1Fin1_ BYTE "El bloque se coloca en la linea ", 0
	$sMod1Fin1 BYTE "El bloque se coloca en el conjunto ", 0
	$sMod1Fin2 BYTE " de la memoria cache.",0

	$n1024 DWORD 1024
	$config DWORD 7 DUP(0)
	$contador BYTE ?
	$divcounter DWORD ?
	$mod2counter DWORD 0
	$DWnumero DWORD ?
	$BloqueCache BYTE 512 DUP('0')
	$BloqueCacheLongitud DWORD 0
	$binario BYTE 512 DUP('0')
	$binarioSICBIC BYTE 200 DUP('0')
	$binarioSICBICLongitud DWORD 0
	$binarioLongitud BYTE 0
	$TAG DWORD ?
	$SIC DWORD ?
	$BIC DWORD ?
	$WIB DWORD ?

	; ----------------------------
	; Variables dedicadas del módulo 1
	; ----------------------------
	$modulo1Name BYTE "Particionamiento de bits de direcciones", 0dh, 0ah, 0dh, 0ah, 0
	$selectMapeoStr BYTE "Esquema de cache: Directo(0), Asociativo(1): ", 0
	$selectUnitStr BYTE 0dh, "Unidad en B(0), KB(1), MB(2): ", 0
	$selectMemPStr BYTE  0dh, "Tamanio de memoria principal: ", 0
	$selectMemCStr BYTE  0dh, "Tamanio de memoria cache: ", 0
	$selectBloqStr BYTE  0dh, "Tamanio del bloque: ", 0
	$selectConjStr BYTE  0dh, "Tamanio de conjuntos: ", 0
	$selectDirStr BYTE  0dh, "Direccion: ", 0

	; ----------------------------
	; Variables dedicadas del módulo 2
	; ----------------------------
	$modulo2Name BYTE "Reemplazo de Bloques (FIFO)", 0dh, 0ah, 0dh, 0ah, 0
	$menu2Str BYTE "1- Cache de 8 bloques y 8 conjuntos.",0dh,0ah,
				  "2- Cache de 16 bloques y 8 conjuntos.",0dh,0ah,
				  "3- Cache de 16 bloques y 4 conjuntos.",0dh,0ah,
				  "Introducir configuracion: ", 0
	$LaSimBegin BYTE "Para salir, introducir la secuencia -1.",0
	$DirStr BYTE "Direccion: ",0
	$statsTotal BYTE "RESULTADOS",0dh,0ah,0dh,0ah,
					"- Total de solicitudes a cache: ",0
	$statsFallas BYTE "- Fallas totales: ", 0
	$statsFallasForz BYTE "	+ Fallas forzosas: ", 0
	$statsFallasConf BYTE "	+ Fallas por conflicto: ", 0
	$statsTasaFallas BYTE "	+ Tasa de fallas: ", 0
	$statsAciertos BYTE "- Aciertos: ", 0
	$statsTasaAciertos BYTE "- Tasa de aciertos: ", 0
	$huboFallaForzosa BYTE "Falla forzosa.",0
	$huboFallaConflicto BYTE "Falla por conflicto: ",0
	$huboAcierto BYTE "Acierto.",0

	$Cache SDWORD 17 DUP(-1) 
	$FifoPointer SDWORD 17 DUP(-1) 
	$NumeroDir SDWORD 0
	$SolicitudesTotales BYTE 0
    $AciertosCount BYTE 0
	$FallaForzosaCount BYTE 0
	$FallaConflictoCount BYTE 0
	$FilasSize DWORD 0
	$ColumnasSize DWORD 0
	$AnchoReal DWORD 0
	$ShowMessagesMod1 BYTE 1 ; Boolan 
	$Conjunto DWORD 0 

; ----------------------------
; Sección de código
; ----------------------------
.code
	; ----------------------------
	; Realiza un salto de línea.
	; -------- params ------------
	Whiteline PROC 
		mov edx, OFFSET $br_str
		call WriteString
		ret
	Whiteline ENDP

	; ----------------------------
	; Algoritmo de reemplazo FIFO, evalúa la próxima posición a sustituir cuando el conjunto está lleno.
	; -------- params ------------
	; esi : Dirección en X de la matriz (Contiene el valor del conjunto en donde se colocará la dirección).
	; $FifoPointer : Contiene información de la posición próxima a sustituir
	; $ColumnasSize : Tamaño interpretado de la columna máxima de la matriz actual 
	; $Cache : La matriz que contiene el caché
	; $NumeroDir : Dirección de memoria que se colocará en el caché
	; -------- return ------------
	; $Cache : Modifica el caché, reemplaza bloques 
	; $FifoPointer : Modificado internamente, para incrementar el contador respectivo del conjunto
	; ----------------------------	
	FifoReplacement PROC 
		; Incremento el FIFO
		mov eax, [$FifoPointer + esi]
		mov ebx, eax ; Guardo la posición actual en donde debo reemplazar
		add eax, 4
		mov [$FifoPointer + esi], eax 

		; Verifico si el FIFO está lleno
		lleno:
			cmp eax, $ColumnasSize
			jl nolleno ; Si es menor, no está lleno.
			mov [$FifoPointer + esi], 0 ; Reinicio el fifo a 0 para que empiece otra véz

		nolleno:
		; Escribo en pantalla a quién voy a reemplazar
		mov eax, [$Cache + esi + ebx] ; Obtengo elemento más reciente que ha entrado 
		mov edx, OFFSET $huboFallaConflicto
		call WriteString 
		call WriteDec ; Imprimo el elemento que reemplazo
		call Whiteline
		inc $FallaConflictoCount

		; Reemplazo el elemento que queda en FIFO por el nuevo
		mov eax, $NumeroDir
		mov [$Cache + esi + ebx], eax

		; Termino la ejecución del programa
		ret
	FifoReplacement ENDP

	; ----------------------------
	; Reemplaza bloques en memoria caché, chequea aciertos y fallas
	; -------- params ------------
	; $AnchoReal : Ancho físico de columnas
	; $FifoPointer : Contiene información de la posición próxima a sustituir
	; $ColumnasSize : Tamaño interpretado de la columna máxima de la matriz actual 
	; $Cache : La matriz que contiene el caché
	; $NumeroDir : Dirección de memoria que se colocará en el caché
	; -------- return ------------
	; $Cache : Modifica el caché, reemplaza bloques 
	; $FifoPointer : Modificado internamente, para incrementar el contador respectivo del conjunto
	; ----------------------------	
	ReplacementCache PROC 
		xor esi, esi
		xor edi, edi ; Pongo esi y edi a cero
		mul $AnchoReal
		mov $DWnumero, 4
		mul $DWnumero
		mov esi, eax ; esi = Conjunto * Ancho  * 4(DWORD)
		mov edi, 0 ; edi es el contador para moverme hacia la derecha
		columna: ; hago la busqueda
			mov eax, [$Cache + esi + edi]
			cmp eax, -1
			je forzosa ; Si es -1, hay falla forzosa en ese sitio porque está vacío y salto a forzosa
			cmp eax, $NumeroDir
			je acierto ; Si hay un acierto en esa posición saltamos a acierto 
			add edi, 4 ; Incrementamos de 4 en 4 por ser un DWORD
		cmp edi, $ColumnasSize
		jle columna

		; Si llega aquí, hay un reemplazo que se debe hacer por FIFO 
		fifo_: 
			call FifoReplacement
			jmp salir

		; Hay falla forzosa
		forzosa:
			cmp [$FifoPointer + esi], -1
			jne nofifo ; Si fifo es -1, está vacío el conjunto porque nadie ha entrado
				mov [$FifoPointer + esi], 0 ; Incremento a 0 (primera posición ocupada)
			nofifo:
				mov eax, $NumeroDir
				mov [$Cache + esi + edi], eax ; Muevo al caché el número
				inc $FallaForzosaCount 
				mov edx, OFFSET $huboFallaForzosa
				call WriteString
				call Whiteline
				jmp salir

		; Hay un acierto
		acierto:
			mov edx, OFFSET $huboAcierto
			call WriteString
			call Whiteline
			inc $AciertosCount

		salir:
			ret
	ReplacementCache ENDP

	; ----------------------------
	; Muestra las estadísticas en pantalla 
	; -------- params ------------
	; $SolicitudesTotales : Solicitudes totales realizadas a caché
	; $FallaConflictoCount : Contador de fallas por conflicto
	; $FallaForzosaCount : Contador de fallas forzosas 
	; $AciertosCount : Contador de aciertos totales
	; ----------------------------	
	ShowReplacementStats PROC
		; Total solicitudes a caché
		mov edx, OFFSET $statsTotal 
		call WriteString 
		movzx eax, $SolicitudesTotales
		call WriteDec
		call Whiteline

		; Total de fallas
		mov edx, OFFSET $statsFallas 
		call WriteString 
		movzx eax, $FallaConflictoCount
		movzx edx, $FallaForzosaCount
		add eax, edx
		call WriteDec
		call Whiteline

		; Fallas forzosas
		mov edx, OFFSET $statsFallasForz
		call WriteString 
		movzx eax, $FallaForzosaCount
		call WriteDec
		call Whiteline

		; Fallas por conflicto
		mov edx, OFFSET $statsFallasConf 
		call WriteString 
		movzx eax, $FallaConflictoCount
		call WriteDec
		call Whiteline

		; Tasa de fallas
		mov edx, OFFSET $statsTasaFallas
		call WriteString 
		movzx eax, $FallaConflictoCount 
		movzx edx, $FallaForzosaCount
		add eax, edx ; Obtengo fallasTotales
		mov $DWnumero, 100
		mul $DWnumero ; fallasTotales * 100 
		movzx edx, $SolicitudesTotales
		call Division ; (fallasTotales * 100) / SolicitudesTotales
		call WriteDec ; Imprimo la parte entera 
		xor eax, eax ; Limpio eax
		mov al, '.'
		call WriteChar ; Imprimo el punto 
		mov eax, edx 
		call WriteDec ; Imprimo la parte decimal
		xor eax, eax ; Limpio eax
		mov al, '%'
		call WriteChar ; Imprimo el signo de porcentaje
		call Whiteline

		; Aciertos totales
		mov edx, OFFSET $statsAciertos 
		call WriteString
		movzx eax, $AciertosCount
		call WriteDec 
		call Whiteline

		; Tasa de aciertos
		mov edx, OFFSET $statsTasaAciertos 
		call WriteString 
		movzx eax, $AciertosCount
		mov $DWnumero, 100
		mul $DWnumero ; AciertosCount * 100 
		movzx edx, $SolicitudesTotales
		call Division ; (AciertosCount * 100) / SolicitudesTotales
		call WriteDec ; Imprimo la parte entera 
		xor eax, eax ; Limpio eax
		mov al, '.'
		call WriteChar ; Imprimo el punto 
		mov eax, edx 
		call WriteDec ; Imprimo la parte decimal
		xor eax, eax ; Limpio eax
		mov al, '%'
		call WriteChar ; Imprimo el signo de porcentaje
		call Whiteline

		ret
	ShowReplacementStats ENDP

	; ----------------------------
	; Muestra la matriz de caché en la pantalla
	; -------- params ------------
	; $FilasSize : Filas interpretadas de la matriz
	; $ColumnasSize : Columnas interpretadas de la matriz
	; $AnchoReal : Ancho físico de columnas
	; ----------------------------
	ShowCache PROC 
		; esi empieza en cero
		mov esi, 0
		mov $contador, 0
		; while esi <= FilasSize
		filas:
			; Muestro que conjunto es el actual
			mov al, 'C'
			call WriteChar
			movzx eax, $contador
			call WriteDec
			mov al, ':'
			call WriteChar
			mov al, ' '
			call WriteChar

			push esi ; apilo
			mov edi, 0 ; edi empieza en cero
			; while edi <= FilasSize
			columnas:
				push edi ; apilo

					; Paréntesis izquierdo
					mov al, '['
					call WriteChar

					; esi *= AnchoReal
					xor eax, eax
					mov eax, esi
					mov $DWnumero, esi ; Guardo el esi actual
					mul $AnchoReal
					mov esi, eax 

					; Obtengo el número actual
					mov eax, [$Cache + esi + edi]
	
					mov esi, $DWnumero ; Regreso el esi a como estaba

					cmp eax, 0
					jl vacio ; eax < 0, es porque la posición está vacía "-1"
					jge novacio ; eax >= 0, es porque en la posición si existe un número que mostrar

					; Si no está vacío, imprimo el número
					novacio:	
						call WriteDec
					jmp cerrarparentesis

					; Si está vacío, imprimo un charter blanco
					vacio: 
						mov al, ' '
						call WriteChar

					cerrarparentesis:
						; Paréntesis derecho
						mov al, ']'
						call WriteChar
	
				pop edi
				add edi, 4 ; edi+=4
			cmp edi, $ColumnasSize
			jle columnas ; edi <= ColumnasSize
			pop esi
		add esi, 4 ; esi+=4
		inc $contador ; Incremento el contador
		; salto de línea
		call Whiteline
		cmp esi, $FilasSize
		jle filas ; esi <= $FilasSize
		
		; Salgo
		ret
	ShowCache ENDP

	; ----------------------------------
	;  Resetea la variable binaria 
	; ----------------------------------
	ResetBin PROC 
		mov $binarioLongitud, 0
		mov ecx, 511
		ciclo:
			mov [$binario + ecx], '0'
		loop ciclo
		mov [$binario], '0'
		ret 
	ResetBin ENDP

	; ----------------------------------
	;  Resetea la variable binaria de sic/BIC
	; ----------------------------------
	ResetBinDec PROC 
		mov $binarioSICBICLongitud, 0
		mov ecx, 199
		ciclo:
			mov [$binarioSICBIC + ecx], '0'
		loop ciclo
		mov [$binarioSICBIC], '0'
		ret
	ResetBinDec ENDP

	; ----------------------------------
	; Resetea la variable binaria del bloque de caché
	; ----------------------------------
	ResetBloqueCache PROC 
		mov $BloqueCacheLongitud, 0
 	    mov ecx, 511
		ciclo: 
			mov [$BloqueCache + ecx], '0'
		loop ciclo
		mov [$BloqueCache], '0'
		ret
	ResetBloqueCache ENDP

	; ----------------------------------
	; Resetea el $Cache
	; ----------------------------------
	ResetCache PROC
		mov esi, 16
		limpiar:
			mov [$Cache + esi*4], -1
			dec esi 
		cmp esi, 0
		jge limpiar
	ResetCache ENDP

	; ----------------------------------
	; Resetea el $FifoPointer
	; ----------------------------------
	ResetFifoPointer PROC
		mov esi, 16
		limpiar:
			mov [$FifoPointer + esi*4], -1
			dec esi 
		cmp esi, 0
		jge limpiar
	ResetFifoPointer ENDP

	; ----------------------------------
	; Limpia variables del módulo 1
	; ----------------------------------
	ResetMod1 PROC 
		mov $WIB, 0
		mov $TAG, 0
		mov $SIC, 0
		mov $BIC, 0
		call ResetBin
		call ResetBinDec
		call ResetBloqueCache
		ret 
	ResetMod1 ENDP 

	; ----------------------------------
	; Limpia variables del módulo 2
	; ----------------------------------
	ResetMod2 PROC 
		mov $SolicitudesTotales, 0 
		mov $AciertosCount, 0
		mov $FallaForzosaCount, 0
		mov $FallaConflictoCount, 0
		mov $FilasSize, 0
		mov $ColumnasSize, 0
		mov $AnchoReal, 0
		mov $ShowMessagesMod1, 0
		mov $Conjunto, 0
		call ResetCache
		call ResetFifoPointer
		ret 
	ResetMod2 ENDP 

	; ----------------------------
	; Multiplica un número por si mismo (Eleva a potencia)
	; -------- params ------------
	; eax : El número base
	; $DWnumero : Tantas veces como se va a multiplicar por sí mismo
	; -------- return ------------
	; eax : Resultado de la operación
	; ----------------------------	
	Raise PROC
		cmp eax, 1
		jl es_cero ; 0 * DWnumero
		je es_uno ; 1 * DWnumero
		cmp $DWnumero, 1
		jl es_cero_d ; eax * 0
		je fin ; eax * 1

		; while eax > 1
		mientras:
			add eax, eax
			dec $DWnumero
		cmp $DWnumero, 1
		jg mientras
		jle fin

		; $DWnumero == 0
		es_cero_d:
			mov eax, 0
			jmp fin

		; eax == 0
		es_cero:
			mov eax, 0
			jmp fin

		; eax == 1
		es_uno:
			mov eax, $DWnumero
			jmp fin
			
		fin:
			ret
	Raise ENDP

	; ----------------------------
	; Divide un número (mejora el funcionamiento de DIV en ASM)
	; -------- params ------------
	; eax : Dividendo
	; edx : Divisor
	; -------- return ------------
	; edx : Residuio de la operación
	; eax : Cociente de la operación
	; ----------------------------	
	Division PROC
		mov $divcounter, 0
		cmp eax, 1
		jl es_cero
		je es_uno

		; while eax > 1
		mientras:
			sub eax, edx
			inc $divcounter
		cmp eax, 1
		jg mientras
		je es_uno
		jl es_cero	

		; eax == 0
		es_cero:
			mov edx, 0
			jmp fin

		; eax == 1
		es_uno:
			mov edx, 1
			jmp fin
			
		fin:
			mov eax, $divcounter
			ret
	Division ENDP

	; ----------------------------
	; Lleva un número da la expresión 2^n a su expresión decimal
	; -------- params ------------
	; eax : n veces a elevar
	; -------- return ------------
	; eax : Resultado de la operación 
	; ----------------------------	
	Base2 PROC
		cmp eax, 0
		je si_es_cero
		cmp eax, 1
		je si_es_uno
		jg si_mayor_uno
		
		si_es_cero:
			mov eax, 1 ; devuelvo uno
		jmp scape

		si_es_uno:
			mov eax, 2 ; devuelvo dos
		jmp scape

		si_mayor_uno:
			mov edx, eax
			mov eax, 1
			mientras:
				mov $DWnumero, 2
				call Raise
				dec edx ; decremento para control del bucle
			cmp edx, 0
			jg mientras ; edx > 0
		
		scape:
		ret
	Base2 ENDP

	; ----------------------------
	; Transforma un número entero al binario correspondiente
	; -------- params ------------
	; $binario : Variable que almacena el vector lleno de '0' inicialmente.
	; eax : Número a transformar, termina siendo cero. 
	; -------- return ------------
	; $binario : Modifica el vector, en función del binario obtenido (BYTE de chars)
	; ---> $binario contiene el binario, pero por defecto está volteado "para su uso posterior conviene así"
	; ecx : Longitud del binario
	; ----------------------------
	IntToBin PROC
		xor ecx, ecx
		cmp eax, 0
		jle scape; eax <= 0

		; while : eax > 0
		mientras:
			; Divido eax / edx, obtengo residuio en edx
			mov edx, 2
			call Division

			; IF edx != 1, si edx == 1 se añade el char
			cmp edx, 1
			jne incremento
				mov[$binario + ecx], '1'

			incremento :
				inc ecx; incremento de ecx

		cmp eax, 0
		jg mientras

		scape:
			ret
	IntToBin ENDP

	; ----------------------------
	; Transforma un vector binario a un número entero.
	; -------- params ------------
	; $binario : Variable que almacena el vector con el binario a transformar.
	; ecx : Longitud del binario (SI NO DESEO PERDER SU VALOR, DEBO GUARDARLO)
	; -------- return ------------
	; eax : Es modificado (el lleva el exponente del bit)
	; ecx : Es modificado (lleva el contador del binario)
	; edx : Controla el bucle interno en Base2
	; ebx : Resultado de la operación (entero convertido)
	; ----------------------------
	BinToInt PROC
		xor ebx, ebx
		xor ecx, ecx
		cmp ecx, $binarioSICBICLongitud
		jge fin
		ciclo:
			mov dl, [$binarioSICBIC + ecx]
			cmp dl, '1'

			jne scape
			; if ([$binarioSICBIC + ecx] == '1')
				mov eax, $binarioSICBICLongitud
				sub eax, ecx
				dec eax
				call Base2
				add ebx, eax
			scape:
				inc ecx; incremento ecx
		cmp ecx, $binarioSICBICLongitud
		jl ciclo
		
		fin:
			ret
	BinToInt ENDP

	; ----------------------------
	; Convierte un número de MB, KB, B a Bytes
	; -------- params ------------
	; eax : Número
	; ecx : Unidad actual (Mb=2/Kb=1/B=0)
	; -------- return ------------
	; eax : Número transformado
	; ----------------------------
	UnitConversor PROC
		cmp ebx, 2
		je si2
		cmp ebx, 1
		jne scape

		; KB
		si1:
			mul $n1024
		jmp scape

		; MB
		si2:
			mul $n1024
			mul $n1024
		jmp scape

		;Byte
		scape:
			ret
	UnitConversor ENDP

	; ----------------------------
	; Obtiene el exponente 'n' de un número que se pueda expresar como 2^n
	; -------- params ------------
	; eax : Número
	; edx : Es modificado internamente
	; -------- return ------------
	; edx : Resultado, devuelve 'n'
	; ----------------------------
	GetExponent PROC
		; Reseteo edx //
		mov $contador, 0

		; Que regrese cero si es 1 eax
		cmp eax, 1
		jg mientras
		mov edx, 0
		jmp scape

		cmp eax, 0
		jle scape ; eax <= 0

		; while : eax > 0
		mientras:
			mov edx, 2
			call Division
			inc $contador ; incremento de ecx
		cmp eax, 1
		jg mientras

		; Salgo
		scape:
			movzx edx, $contador ; Doy la respuesta, del n //
			ret
	GetExponent ENDP

	; ----------------------------
	; Módulo 1 (Menú y operaciones)
	; Es reutilizado todo en el módulo 2
	; -------- params ------------
	; $ShowMessagesMod1 : Booleana (interpretada), que dice si se va a mostrar o no información en pantalla.
	; -------- return ------------
	; Conjunto : Si se llama desde el módulo 2, devuelve el conjunto en el que se coloca una dirección.
	; ----------------------------
	modulo1 PROC
		call ResetMod1
	
		; Verificamos si estamos accediendo desde el módulo 2
		cmp $ShowMessagesMod1, 0
		je mostrarenconsola ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones

		call ClrScr
		
		; Título del módulo 
		mov edx, OFFSET $modulo1Name
		call WriteString

		; Seleccionar mapeo
		mov edx, OFFSET $selectMapeoStr
		call WriteString
		call ReadDec
		mov [$config], eax

		; Tamaño memoria principal
		mov edx, OFFSET $selectMemPStr
		call WriteString
		call ReadDec
		mov [$config + 4], eax

		; Unidad de la memoria 
		mov edx, OFFSET $selectUnitStr
		call WriteString
		call ReadDec
		mov [$config + 24], eax; Recibo la unidad 
		mov eax, [$config + 4] ; Coloco de nuevo el valor de la memoria introducido antes para UnitConversor 
		mov ebx, [$config + 24]; Guardo la unidad en ebx para UnitConversor 
		call UnitConversor
		mov [$config + 4], eax

		; Salto de linea 
		call Whiteline

		; Tamaño memoria cache 
		mov edx, OFFSET $selectMemCStr
		call WriteString
		call ReadDec
		mov [$config + 8], eax
		
		; Unidad de la memoria 
		mov edx, OFFSET $selectUnitStr
		call WriteString
		call ReadDec
		mov [$config + 24], eax; Recibo la unidad 
		mov eax, [$config + 8]; Coloco de nuevo el valor de la memoria introducido antes para UnitConversor 
		mov ebx, [$config + 24]; Guardo la unidad en ebx para UnitConversor 
		call UnitConversor
		mov [$config + 8], eax

		; Salto de linea 
		call Whiteline

		; Tamaño de bloques 
		mov edx, OFFSET $selectBloqStr
		call WriteString
		call ReadDec
		mov [$config + 12], eax

		; Unidad de la memoria 
		mov edx, OFFSET $selectUnitStr
		call WriteString
		call ReadDec
		mov [$config + 24], eax; Recibo la unidad 
		mov eax, [$config + 12]; Coloco de nuevo el valor de la memoria introducido antes para UnitConversor   
		mov ebx, [$config + 24]; Guardo la unidad en ebx para UnitConversor 
		call UnitConversor
		mov [$config + 12], eax

		; Salto de linea 
		call Whiteline

		; Tamaño de conjuntos SI es asociativo 
		mov edx, [$config]
		cmp edx, 1
		jne si1_nocumple ; edx != 1, si edx == 1 entra en si1:
		si1:
			mov edx, OFFSET $selectConjStr
			call WriteString
			call ReadDec
			mov [$config + 16], eax

			; Salto de linea 
			call Whiteline
		si1_nocumple:

		; Dirección de memoria 
		mov edx, OFFSET $selectDirStr
		call WriteString
		call ReadDec
		mov [$config + 20], eax

		; Si llega aquí, fue por un salto implicito desde el módulo 2 o por el flujo normal
		mostrarenconsola:

		; Transformo la direccion de memoria a binario que está en eax 
		call IntToBin
		; ecx tiene la longitud del binario 
		dec ecx ; Disminuyo el exceso de ecx para recorrer las posiciones del binario
		mov $binarioLongitud, cl ; Guardar la longitud del binario

		; TAG = Memoria principal(en bytes) / memoria cache(bytes), en potencia de 2
		; BIC = Memoria caché (en bytes) / bloques(en bytes), en potencia de 2
		; WIB = bloques(en bytes), en potencia de 2
		; Calculo en mapeo directo
		mov edx, [$config]
		cmp edx, 0
		jne si2_nocumple ; edx != 0, si edx == 0 entra en si2:
		si2:
			; Creación del TAG 
			mov eax, [$config + 4]
			call GetExponent 
			mov $TAG, edx ; A TAG le asigno edx, que será el exponente de mem principal
			mov eax, [$config + 8]
			call GetExponent 
			sub $TAG, edx ; A TAG (exp. memppal) le resto el exp. de mem cache

			; Creación del BIC 
			mov eax, [$config + 8]
			call GetExponent
			mov $BIC, edx; A BIC le asigno ecx, que será el exponente de bloque
			mov eax, [$config + 12]
			call GetExponent
			sub $BIC, edx; A BIC (exp. memcach) le resto el exp. de bloque

			; Creación del WIB 
			mov $WIB, edx; Por la operación anterior, en edx estaba el BIC
		si2_nocumple:

		; TAG = M.P - SIC - WIB
		; SIC = (Memoria caché (en bytes) / bloques (en bytes)) / tamaño de conjunto, en potencia de 2
		; WIB = bloques(en bytes), en potencia de 2
		; Calculo en mapeo asociativo por conjunto
		mov edx, [$config]
		cmp edx, 1
		jne si3_nocumple ; edx != 1, si edx == 1 entra en si3:
		si3:
			; Creación del WIB 
			mov eax, [$config + 12]
			call GetExponent
			mov $WIB, edx

			; Creación del SIC 
			mov eax, [$config + 8]
			call GetExponent
			mov $SIC, edx
			mov eax, $WIB
			sub $SIC, eax
			mov eax, [$config + 16]
			call GetExponent
			sub $SIC, edx

			; Creación del TAG
			mov eax, [$config + 4]
			call GetExponent
			mov $TAG, edx
			mov eax, $SIC
			sub $TAG, eax
			mov eax, $WIB 
			sub $TAG, eax		
		si3_nocumple:

		; Defino el tamaño del vector BloqueCache
		mov eax, $TAG 
		add eax, $BIC 
		add eax, $SIC 
		add eax, $WIB 
		dec eax
		mov $BloqueCacheLongitud, eax ; TAG + BIC + SIC + WIB

		; LLENO BloqueCache con binario, en las ultimas posiciones de binario 
		xor ecx, ecx
		xor eax, eax
		cmp cl, $binarioLongitud
		jg finmientras1 ; cl > binarioLongitud salta, si no entra en el while
		; while : cl <= binarioLongitud
		mientras1:
			mov dl, [$binario + ecx]
			mov eax, $BloqueCacheLongitud
			sub eax, ecx
			mov[$BloqueCache + eax], dl
			inc cl
			cmp cl, $binarioLongitud
		jle mientras1
		finmientras1: 

		cmp $ShowMessagesMod1, 0
		je mostrarenconsola2 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
			; Salto de línea 
			call Whiteline
		
			; Mostrar el TAG 
			mov edx, OFFSET $sTAG
			call WriteString
		mostrarenconsola2:

		xor ecx, ecx
		xor eax, eax
		cmp ecx, $TAG
		jge finmientras2 ; ecx >= TAG no entra, si es < TAG sí
		mientras2:
			cmp $ShowMessagesMod1, 0
			je mostrarenconsola3 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
				mov al, '['
				call WriteChar
				mov al, [$BloqueCache + ecx]
				call WriteChar
				mov al, ']'
				call WriteChar
			mostrarenconsola3:
				inc ecx
		cmp ecx, $TAG
		jl mientras2 ; ecx < TAG
		finmientras2:

		cmp $ShowMessagesMod1, 0
		je mostrarenconsola4 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
			; Salto de línea 
			call Whiteline
		mostrarenconsola4:

		mov edx, [$config]
		cmp edx, 0
		jne sibic_nocumple ; edx != 0, si edx == 0 entra en sibic:
			mov ebx, $BIC
		sibic_nocumple:
			cmp edx, 1
			jne sisic_nocumple
				mov ebx, $SIC
		sisic_nocumple:	
		mov $binarioSICBICLongitud, ebx

		; Incremento el BIC += $TAG
		mov eax, $BIC 
		add eax, $TAG 
		mov $BIC, eax

		; Incremento el SIC += $TAG
		mov eax, $SIC 
		add eax, $TAG 
		mov $SIC, eax

		cmp $ShowMessagesMod1, 0
		je mostrarenconsola5 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
			; Muestro el BIC si es directo el mapeo 
			mov edx, [$config]
			cmp edx, 0
			jne si4_nocumple ; edx != 1, si edx == 1 entra en si3:
			si4:
				xor ebx, ebx ; contador ebx para binarioSICBIC

					mov edx, OFFSET $sBIC
					call WriteString

				xor eax, eax
				cmp ecx, $BIC 
				jge si4_nocumple ; ecx >= BIC  no entra, si es < BIC sí
				mientras3:

						mov al, '['
						call WriteChar
						mov al, [$BloqueCache + ecx]
						mov [$binarioSICBIC + ebx], al ; Asigno al binario la particion del BIC
						call WriteChar
						mov al, ']'
						call WriteChar
					inc ecx
					inc ebx ; contador ebx para binarioSICBIC
				cmp ecx, $BIC
				jl mientras3 ; ecx < BIC
			si4_nocumple:
		mostrarenconsola5:

		; Muestro el SIC si es asociativo el mapeo
		mov edx, [$config]
		cmp edx, 1
		jne si5_nocumple ; edx != 1, si edx == 1 entra en si3:
		si5:
			xor ebx, ebx ; contador ebx para binarioSICBIC

			cmp $ShowMessagesMod1, 0
			je mostrarenconsola6 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
				mov edx, OFFSET $sSIC
				call WriteString
			mostrarenconsola6:

			xor eax, eax
			cmp ecx, $SIC
			jge si5_nocumple ; ecx >= SIC  no entra, si es < SIC sí
			mientras4:
					cmp $ShowMessagesMod1, 0
					je mostrarenconsola7 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
						mov al, '['
						call WriteChar
					mostrarenconsola7:
						mov al, [$BloqueCache + ecx]
						mov [$binarioSICBIC + ebx], al ; Asigno al binario la particion del SIC
					cmp $ShowMessagesMod1, 0
					je mostrarenconsola88 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones	
						call WriteChar
						mov al, ']'
						call WriteChar
					mostrarenconsola88:
				inc ecx
				inc ebx ; contador ebx para binarioSICBIC
			cmp ecx, $SIC
			jl mientras4 ; ecx < SIC
		si5_nocumple:

		cmp $ShowMessagesMod1, 0
		je mostrarenconsola8 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
			; Salto de línea 
			call Whiteline
		mostrarenconsola8:
		
		; Incremento el WIB += TAG + (SIC ó BIC)
		mov eax, $BloqueCacheLongitud
		mov $WIB, eax

		cmp $ShowMessagesMod1, 0
		je mostrarenconsola9 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
			; Muestro el WIB 
			mov edx, OFFSET $sWIB
			call WriteString
		mostrarenconsola9:

		xor eax, eax
		cmp ecx, $WIB
		jge finmodulo ; ecx >= WIB  no entra, si es < WIB sí
		mientras5:

		cmp $ShowMessagesMod1, 0
		je mostrarenconsola10 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
				mov al, '['
				call WriteChar
				mov al, [$BloqueCache + ecx]
				call WriteChar
				mov al, ']'
				call WriteChar
		mostrarenconsola10:

			inc ecx
		cmp ecx, $WIB
		jle mientras5 ; ecx <= WIB
		
		finmodulo:			
		cmp $ShowMessagesMod1, 0
		je mostrarenconsola11 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
			; Salto de línea 
			call Whiteline
		
			mov edx, [$config]
			cmp edx, 1
			jne si6_nocumple ; edx != 1, si edx == 1 entra en si3:
			si6:
				mov edx, OFFSET $sMod1Fin1
				jmp si6_nocumplex2
			si6_nocumple:
				mov edx, OFFSET $sMod1Fin1_
			si6_nocumplex2:
			call WriteString
		mostrarenconsola11:

		call BinToInt
		mov eax, ebx
		mov $Conjunto, eax ; Capturo el conjunto para usarlo en el modulo 2

		cmp $ShowMessagesMod1, 0
		je mostrarenconsola12 ; si $ShowMessagesMod1 == 0, no muestro ningun mensaje ni pido configuraciones
			call WriteDec
			mov edx, OFFSET $sMod1Fin2 
			call WriteString

			; Solo para que no se cierre la pantalla //
			call ReadChar 
		mostrarenconsola12:

		ret
	modulo1 ENDP 

	; ----------------------------
	; Módulo 2 (Menú y operaciones)
	; ----------------------------
	modulo2 PROC 
		; Limpiar registros y variables
		call ResetMod2
		menumodulo2:
			; Limpio Pantalla
			call ClrScr
			; Imprimo nombre del modulo
			mov edx, OFFSET $modulo2Name
			call WriteString
			call Whiteline 
			; Imprimo el menú
			mov edx, OFFSET $menu2Str
			call WriteString
			; Solicito opción
			xor eax, eax
			call ReadDec
			; Verifico que ha elegido 
			cmp eax, 1
			je cache1op ; Si es 1, configuro a caché 1
			jl menumodulo2 ; Si es < 1, vuelvo a mostrar el menú
			cmp eax, 2
			je cache2op ; Si es 2, configuro a caché 2
			cmp eax, 3 
			je cache3op ; Si es 3, configuro a caché 3
			jg menumodulo2 ; Si es > 3, vuelvo a mostrar el menú 

			cache1op:
				mov $FilasSize, 31 ; 32 
				mov $ColumnasSize, 3 ; 4  
				mov $AnchoReal, 1 ; 8x1 matriz
				mov [$config + 8], 16 ; tamaño de memoria caché
				mov [$config + 16], 2 ; tamaño de conjuntos
				jmp empezarmodulo2

			cache2op:
				mov $FilasSize, 31 ; 32
				mov $ColumnasSize, 7 ; 8
				mov $AnchoReal, 2 ; 8x2  matriz
				mov [$config + 8], 16 ; tamaño de memoria caché
				mov [$config + 16], 2 ; tamaño de conjuntos
				jmp empezarmodulo2

			cache3op:
				mov $FilasSize, 15 ; 16
				mov $ColumnasSize, 15 ; 16
				mov $AnchoReal, 4 ; 4x4 matriz
				mov [$config + 8], 16 ; tamaño de memoria caché
				mov [$config + 16], 4 ; tamaño de conjuntos

			empezarmodulo2:
				mov [$config], 1 ; mapeo asociativo
				mov [$config + 4], 64 ; tamaño memoria principal
				mov [$config + 12], 1 ; tamaño de bloques

				; limpiamos la pantalla para empezar a pedir las direcciones de memoria 
				call Whiteline
				mov edx, OFFSET $LaSimBegin
				call WriteString

				; Empezamos a pedir direcciones de memoria (20 veces)
				call Whiteline 
				call Whiteline
				mov $mod2counter, 19
				
				pedirdirecciones:
				mov edx, OFFSET $DirStr
					call WriteString
					call ReadInt
					
					mov $NumeroDir, eax
					cmp eax, -1 
					je salirciclo

					mov [$config + 20], eax ; Guardamos el número de la dirección
					mov $ShowMessagesMod1, 0 ; Le decimos al modulo 1 que no muestre ni pida datos
					call modulo1 ; LLamo al módulo uno para que procese la información 
					call ReplacementCache
					inc $SolicitudesTotales; Incrementamos las solicitudes a caché realizadas
									
				dec $mod2counter
				mov ecx, $mod2counter
				cmp ecx, 0
				jge pedirdirecciones

				salirciclo:
				; Mostramos la memoria caché
				call Whiteline
				call Whiteline
				call ShowCache

				; Mostramos las estadísticas 
				call Whiteline 
				call Whiteline
				call ShowReplacementStats
		ret
	modulo2 ENDP
	
	; ----------------------------
	; Menú principal
	; ----------------------------
	MenuPpal PROC 
		xor eax, eax

		cmp eax, 1
		je si1 ; eax == 1
		cmp eax, 2
		je si2 ; eax == 2
		cmp eax, 3
		je scape ; eax == 3
		cmp eax, 4
		je scape ; eax == 4

		; while: (eax < 1) || (eax > 4)
			mientras:
				call ClrScr
				mov edx, OFFSET $menuStr
				call WriteString
				call ReadDec
			cmp eax, 1
			jl mientras
			cmp eax, 4
			jg mientras
		
		; Arrancamos el módulo 1 
		cmp eax, 1
		jne si1_nocumple ; eax != 1 salta, si eax == 1 entra en si1
		si1:
			mov $ShowMessagesMod1, 1
			call modulo1
		si1_nocumple:

		; Arrancamos el módulo 2 
		cmp eax, 2
		jne scape ; eax != 2 salta, si eax == 2 entra en si2
		si2:
			call modulo2

		scape:
			ret
	MenuPpal ENDP	

	; ----------------------------
	; void Main()
	; ----------------------------
	main PROC 
		siguiente: 	
			call ClrScr
			call MenuPpal

		seguir:  
			call Whiteline
			call Whiteline
			mov edx, OFFSET $menuRegreso
			call WriteString
			call ReadDec
			cmp eax,1 
			je siguiente
			cmp eax,2
			je Fin
			jg seguir
			jl seguir 
		
		Fin:	
			exit
   	main ENDP
END main