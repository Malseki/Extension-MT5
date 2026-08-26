//+------------------------------------------------------------------+
//| TRADER-CALENDAR-BACKFILL.mq5                                      |
//|                                                                   |
//| Vuelca el calendario nativo con una ventana ANCHA, de una sola    |
//| pasada, para rellenar el historico hacia atras.                   |
//|                                                                   |
//| POR QUE EXISTE                                                    |
//| TRADER-ALERT-001 vuelca -48h..+96h cada 5 minutos. Sirve para      |
//| event risk, que es lo que necesita, pero SPEC-FUND-001 §5 pide una |
//| ventana movil de 10 dias habiles para M3. Esa ventana no se puede  |
//| reconstruir acumulando snapshots hacia adelante sin esperar dos    |
//| semanas.                                                          |
//|                                                                   |
//| El calendario del terminal, en cambio, ya tiene la historia: la    |
//| limitacion de -48h es del volcado, no de la fuente. Este script la |
//| lee entera una vez y la deja en un CSV que el acumulador mergea.   |
//|                                                                   |
//| NO reemplaza al detector ni escribe TRADER-CALENDAR.csv: escribe   |
//| su propio archivo, para que un backfill no pueda pisar la fuente   |
//| en vivo de la que depende el event risk.                          |
//|                                                                   |
//| Es de UNA CORRIDA. Se ejecuta a mano sobre cualquier grafico.      |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

input int InpDaysBack    = 120;   // dias hacia atras a volcar
input int InpDaysForward = 7;     // dias hacia adelante

//| Los valores del calendario vienen multiplicados por 1e6, y LONG_MIN
//| significa "no hay valor". Sin esa distincion un dato ausente se leeria
//| como cero, que es un numero creible y completamente falso.
bool   CalHas(const long v) { return(v != LONG_MIN); }
string CalTxt(const long v)
  {
   if(v == LONG_MIN) return("");           // vacio, NUNCA cero
   return(DoubleToString((double)v / 1000000.0, 3));
  }

void OnStart()
  {
   int fh = FileOpen("TRADER-CALENDAR-BACKFILL.csv",
                     FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON
                     | FILE_SHARE_READ | FILE_SHARE_WRITE, ',');
   if(fh == INVALID_HANDLE)
     {
      Print("BACKFILL: no pude abrir el CSV, error ", GetLastError());
      return;
     }

   FileWrite(fh, "event_time_server", "currency", "importance", "event",
             "actual", "forecast", "previous", "has_actual", "dumped_at");

   datetime from = TimeCurrent() - (datetime)InpDaysBack * 86400;
   datetime to   = TimeCurrent() + (datetime)InpDaysForward * 86400;
   string cur[2]; cur[0] = "USD"; cur[1] = "EUR";
   string now = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);

   int total = 0, withActual = 0;

   for(int c = 0; c < 2; c++)
     {
      MqlCalendarValue v[];
      int n = CalendarValueHistory(v, from, to, NULL, cur[c]);
      if(n <= 0)
        {
         Print("BACKFILL: ", cur[c], " devolvio ", n,
               " valores, error ", GetLastError());
         continue;
        }
      for(int i = 0; i < n; i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(v[i].event_id, ev)) continue;
         if(ev.importance == CALENDAR_IMPORTANCE_NONE) continue;
         if(ev.importance == CALENDAR_IMPORTANCE_LOW)  continue;
         string nm = ev.name; StringReplace(nm, ",", " ");
         string imp = (ev.importance == CALENDAR_IMPORTANCE_HIGH)
                      ? "HIGH" : "MODERATE";
         bool has = CalHas(v[i].actual_value);
         FileWrite(fh, TimeToString(v[i].time, TIME_DATE | TIME_MINUTES),
                   cur[c], imp, nm,
                   CalTxt(v[i].actual_value), CalTxt(v[i].forecast_value),
                   CalTxt(v[i].prev_value),
                   (has ? "YES" : "NO"), now);
         total++;
         if(has) withActual++;
        }
     }

   FileClose(fh);
   PrintFormat("BACKFILL listo: %d eventos, %d con actual, ventana %s .. %s",
               total, withActual,
               TimeToString(from, TIME_DATE), TimeToString(to, TIME_DATE));
  }
