# SPEC-RB-IDM-001 — Rejection Block e Inducement

Derivado de las transcripciones de los 7 videos (`spec/videos-trader/`).
**Escrito antes de medir ningun resultado.** Fecha: 2026-09-03.

Motivo: la version mecanica de la estrategia (E-MT5-039) encuentra 0,65 setups
por mes. El trader reporta 12 en pocos dias. La diferencia esta en estos dos
conceptos, que hasta ahora estaban declarados como NO implementados.

---

## 1. REJECTION BLOCK

### Lo que dicen los videos

> v2: *"el precio liquida minimo de Asia / y tenemos aca esta Rejection, que el
> precio viene a reaccionar"*
> v2: *"a muy simple vista, tenes aca una Rejection Block / que tambien estaba
> en dos minutos"*
> v2: *"fijense que el precio toma la liquidez / reacciona la Rejection / y entre"*
> v2: *"esta vela abre inclusive arriba de esta vela / que deja un poco de
> rechazo en la zona de la Rejection"*
> v4: *"primero liquida el minimo a las 2.30, vuelve a retestear la zona, me
> deja este Rejection Block de aca"*
> v3: *"Vela tipo rejection block / La cual reacciona"*

### Lectura

El Rejection Block **es la vela que produjo la toma de liquidez**: la que metio
la mecha mas alla del nivel y cerro de vuelta. Despues se convierte en una zona
a la que el precio **vuelve** ("vuelve a retestear") y desde la que reacciona.
La entrada es en ese retest, no en la toma.

### Definicion operativa

Dada una barra `i` que barre un nivel `L` en direccion `dir`:

1. La vela `i` penetra `L` por >= 0,5 pip y **cierra del lado original**.
2. La **mecha del lado del barrido** mide >= 50% del rango total de la vela.
   (es lo que hace que sea "rechazo" y no simple continuacion)
3. **Zona RB**:
   - barrido de maximo (dir = venta): desde `max(open, close)` hasta `high`
   - barrido de minimo (dir = compra): desde `min(open, close)` hasta `low`
4. **Confirmacion multi-temporal**: existe una vela con la misma forma y zona
   solapada en M3 **o** M5. v2 lo dice explicito: *"tambien estaba en dos minutos"*.
5. **Disparo**: el precio vuelve a entrar en la zona RB dentro de los 60 min.

### Lo que queda como eleccion mia y no del video

- el 50% de mecha (el video dice "rechazo", no da numero)
- los 60 min de validez
- usar M3/M5 como confirmacion (el video nombra "dos minutos", que MT5 no tiene
  como temporalidad estandar; M3 es la mas cercana hacia arriba)

Estan marcadas para que se puedan corregir con datos etiquetados (§3).

---

## 2. INDUCEMENT

### Lo que dicen los videos

> v2: *"ya habiamos tenido un impulso bastante fuerte / que se lleva a estas
> anteriores velas / dejandonos el Indusment y rompiendo la estructura con
> bastante fuerza"*
> v4: *"Y con un Indusment de aca, asi que estoy especulando con que saque el
> Indusment, toque la Rejection y se vaya"*
> v4: *"Lo vamos a tratar como liquidez, mas que como Indusment. Esto ya no me
> sirve. Hipotesis quedo vieja."*
> v3: *"Esto podria llegar a ser un inducement"*

### Lectura

El Inducement es un **maximo o minimo menor que queda entre el precio actual y
la zona real** (el Rejection Block o el FVG). Es la trampa: ahi estan los stops.
La secuencia que el trader espera es **primero se toma el inducement, despues el
precio llega a la zona, y recien ahi se va**.

v4 es la clave de cuando NO vale: si el inducement se toma y no pasa lo
esperado, deja de ser inducement y pasa a ser simplemente liquidez. El propio
trader descarta su hipotesis en vivo.

### Definicion operativa

Despues del CHoCH y antes de la entrada:

1. Se busca el **pivote menor (2/2) mas reciente en direccion contraria al
   trade**, situado **entre el precio del CHoCH y la zona de entrada**.
2. Ese pivote es el Inducement.
3. **Setup con inducement tomado**: el precio penetra ese pivote por >= 0,3 pip
   **antes** de tocar la zona. Es la secuencia de v4.
4. **Setup sin inducement**: el precio llega a la zona sin haberlo tomado.
5. Si no existe ningun pivote menor entre medio, el setup es "sin inducement
   disponible" — categoria distinta de "no tomado".

**El inducement NO filtra.** Se registra en tres categorias (`tomado`,
`no_tomado`, `no_habia`) porque v4 muestra al trader cambiando de opinion sobre
el mismo nivel en vivo. Convertirlo en filtro seria fingir una certeza que el
video no tiene.

---

## 3. QUE MEDICION HACE FALTA PARA SER PRECISO

Esto es lo que el detector NO puede resolver solo, y es la pregunta concreta.

### 3.1 Lo que falta: ejemplos etiquetados

Las tres decisiones marcadas arriba (50% de mecha, 60 min, M3/M5) son mias, no
del video. Cualquiera de las tres cambia cuantos casos aparecen. Para fijarlas
no hace falta que el trader escriba reglas: **alcanza con que marque casos**.

La medicion concreta que hace falta es:

> Una lista de **fecha y hora exacta** (con la zona horaria de su grafico) de
> instancias que el trader considere Rejection Block **y de instancias que
> NO lo sean pero se le parezcan**. Idem para Inducement.
> Con **15-20 de cada** alcanza para fijar los umbrales.

Los negativos son tan necesarios como los positivos: sin ellos no hay forma de
saber si la definicion es demasiado laxa.

### 3.2 Como se convierte en una tarea facil

En vez de pedirle que busque casos, el detector genera **candidatos con fecha,
hora y precio**, y el trader responde si / no sobre cada uno. Eso convierte un
problema de especificacion en una tarea de etiquetado.

Es lo que produce `E-MT5-040-rb-idm-scan.mq5`.

### 3.3 Calibracion por FRECUENCIA, no por resultado

Mientras no haya etiquetas, hay un ancla que si se puede usar sin contaminar
nada: **cuantos setups por dia**.

El trader reporta 12 operaciones en pocos dias. Una definicion que produce 0,65
por mes esta mal por frecuencia sola, sin mirar si gana o pierde. La frecuencia
es observable y no filtra por resultado, asi que calibrar contra ella **no es
ajuste de curva**.

Criterio fijado ahora, antes de medir:

| setups/dia que produzca la definicion | lectura |
|---|---|
| < 0,3 | demasiado estricta, no es lo que hace el trader |
| 0,5 - 3 | compatible con lo que reporta |
| > 6 | demasiado laxa, esta marcando ruido |

### 3.4 Lo que sigue sin poder medirse

- **Zona horaria exacta de su grafico.** Se derivo ET−1 de v3
  (*"apertura de Nueva York, son las 8 y cuarto, faltan 15 minutos"*), y encaja
  con sus 12 horarios y con v4. Pero es inferencia, no dato.
- **Cuantos setups VE contra cuantos TOMA.** Los 12 son los tomados. Si ve 30 y
  toma 12, la frecuencia objetivo es otra.
