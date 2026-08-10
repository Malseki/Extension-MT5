# PROJECT TRADER — Extension MetaTrader 5

Detector de setups con alertas para MT5. **Nunca opera solo**: detecta, avisa,
y el humano decide y ejecuta.

## Estado del proyecto

**La pregunta economica esta cerrada.** Ver [`spec/FINDINGS-001-what-we-know.md`](spec/FINDINGS-001-what-we-know.md)
para las conclusiones consolidadas con su evidencia sellada.

En una linea: el mercado intradia **si** tiene una ineficiencia medible
(reversion tras impulsos, 52.81%, z=+18.50 sobre 108,678 casos virgenes), y
**no** es explotable por un tomador de liquidez retail, porque el costo de
acceder a ella sube justo cuando aparece (el spread en el instante de la senal
es 1.3-2.0x su propio promedio, lo que da 1.5-3.6x la ventaja completa).

## Que corre hoy

| componente | que hace |
|---|---|
| `spec/experiments/mt5/TRADER-ALERT-001.mq5` | detector + alerta en vivo, panel arrastrable, registro forward |
| `dashboard/server.py` | panel web legible en http://127.0.0.1:8791 |
| `INICIAR TRADER.command` (Escritorio) | arranca todo con doble clic |
| `engine/` | motor de referencia en Python + gates adversariales |

## Como arrancarlo

Doble clic en **`INICIAR TRADER.command`** en el Escritorio. Abre MT5 con la
extension cargada, levanta el panel web y te lo muestra en el navegador.

## Protocolo (no negociable)

- Especificacion antes que codigo; decisiones antes que implementacion.
- Cada afirmacion etiquetada `[OBSERVED] [DERIVED] [INFERRED] [NOT ESTABLISHED]`.
- Prohibido el curve fitting: no se barren parametros, no se eligen umbrales
  despues de ver el P&L, no se acorta el periodo hasta que de positivo.
- Todo experimento se pre-registra ANTES de medir y se sella con SHA-256 en
  `spec/experiments/mt5/raw/`.
- Un resultado negativo es un resultado valido y no se maquilla.
- El umbral economico se recalcula **por instrumento** (leccion de E-MT5-031).
- Todo experimento lleva control positivo (leccion de E-MT5-022).

## Experimentos sellados

Cada uno con su MANIFEST y SHA256SUMS en `spec/experiments/mt5/raw/`.
Los mas importantes:

| id | que establecio |
|---|---|
| E-MT5-022 | el patron 1-2-3 refutado a -7 sigma sobre 12 anios OOS |
| E-MT5-024 | la ley del impuesto de ejecucion `1/3 - s/(3D)` |
| E-MT5-028 | H-FOCAL refutado sobre GBPUSD virgen |
| E-MT5-029 | variance ratio: reversion a toda escala intradia |
| E-MT5-030 | los impulsos revierten, no continuan |
| E-MT5-031 | reversion confirmada sobre 108,678 casos virgenes |
| E-MT5-032 | el spread se duplica en el instante de la senal |
