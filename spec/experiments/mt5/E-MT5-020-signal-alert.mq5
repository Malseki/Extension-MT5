//+------------------------------------------------------------------+
//| E-MT5-020 — ALERTA DE SETUP  (SOLO AVISA, NO OPERA)               |
//|                                                                  |
//| *** NO enlaza ninguna funcion de trading. Sin <Trade\Trade.mqh>,  |
//| *** sin OrderSend, sin PositionOpen. NO PUEDE abrir una posicion  |
//| *** aunque se lo pidas. Vos decidis y vos apretas el boton.       |
//|                                                                  |
//| Detecta el patron 1-2-3 y te dice literalmente COMPRAR o VENDER,  |
//| con entrada, stop, objetivo, lotes y los pasos exactos del        |
//| terminal para ejecutarlo a mano.                                  |
//|                                                                  |
//| ADVERTENCIA ECONOMICA, y no la voy a esconder detras del panel:   |
//| esta regla NO tiene rentabilidad demostrada. El unico backtest    |
//| economico completo (hist2) termino en $10.15 sobre $10,000, con   |
//| profit factor 0.80. El pad de stop X=5 que usa este archivo       |
//| CONTRADICE DEC-LOCK-001 seccion 9 y no fue aprobado por nadie.    |
//| El panel muestra esa advertencia de forma permanente.             |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - alerta de setup"
#property version   "1.0"
#property strict

input int    InpRefK        = 3;      // A' K, LOCKED
input int    InpStopPadPts  = 5;      // OPEN, contradice DEC-LOCK-001 sec.9 (dice 1, sin pad)
input double InpTargetR     = 2.0;    // LOCKED, PROVISIONAL
input double InpRiskPct     = 1.0;    // % del balance a arriesgar
input double InpBalanceFijo = 0;      // 0 = usar el balance real de la cuenta
input bool   InpPopup       = true;   // ventana emergente + sonido
input bool   InpPush        = false;  // notificacion al celular (requiere MetaQuotes ID)
input bool   InpDibujar     = true;

#define PFX "AL_"
struct Bar { datetime t; double o,h,l,c; };

datetime gLastBar = 0;
int      gSenales = 0;
string   gUltima  = "sin senales todavia";

//====================================================================
double Ext(const Bar &b,const int d){ return(d>0 ? b.l : b.h); }

bool DetectAt(const Bar &b[],const int i3,const int K,const int d,
              double &ref,double &sweep,double &rejc)
  {
   int i2=i3-1, i1=i3-2;
   if(i1-K<0) return(false);
   ref=Ext(b[i1],d);
   for(int k=1;k<=K;k++) if(d*(Ext(b[i1-k],d)-ref)<=0.0) return(false);
   sweep=Ext(b[i2],d);
   if(!(d*(sweep-ref)<0.0))        return(false);
   if(!(d*(sweep-b[i2].c)<0.0))    return(false);
   if(!(d*(b[i2].c-ref)<0.0))      return(false);
   rejc=b[i3].c;
   if(!(d*(rejc-sweep)>=0.0))      return(false);
   return(true);
  }

bool Contiguo(const Bar &b[],const int i3,const datetime entT,const int ps)
  {
   if(b[i3].t   - b[i3-1].t != ps) return(false);
   if(b[i3-1].t - b[i3-2].t != ps) return(false);
   if(entT      - b[i3].t   != ps) return(false);
   return(true);
  }

//====================================================================
int OnInit()
  {
   if(_Period!=PERIOD_M5)
      Print("AVISO: la regla esta especificada en M5. Este grafico es ",
            EnumToString((ENUM_TIMEFRAMES)_Period));
   Panel();
   Print("E-MT5-020 activo. NO opera. Solo avisa. trade_mode=",
         (int)AccountInfoInteger(ACCOUNT_TRADE_MODE)," (0=DEMO 2=REAL)");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int r){ ObjectsDeleteAll(0,PFX); }

//====================================================================
void OnTick()
  {
   datetime bt=iTime(_Symbol,_Period,0);
   if(bt==gLastBar || bt==0){ Panel(); return; }
   gLastBar=bt;

   int need=InpRefK+4;
   Bar b[]; ArrayResize(b,need);
   for(int i=0;i<need;i++)
     { int sh=need-1-i;
       b[i].t=iTime(_Symbol,_Period,sh); b[i].o=iOpen(_Symbol,_Period,sh);
       b[i].h=iHigh(_Symbol,_Period,sh); b[i].l=iLow(_Symbol,_Period,sh);
       b[i].c=iClose(_Symbol,_Period,sh); }
   int i3=need-2, ps=PeriodSeconds();

   for(int d=1; d>=-1; d-=2)
     {
      double ref,sw,rj;
      if(!DetectAt(b,i3,InpRefK,d,ref,sw,rj)) continue;
      if(!Contiguo(b,i3,bt,ps)) break;         // hueco temporal: no es senal
      Avisar(d,b,i3,ref,sw,rj);
      break;
     }
   Panel();
  }

//====================================================================
void Avisar(const int d,const Bar &b[],const int i3,
            const double ref,const double sw,const double rj)
  {
   MqlTick tk; if(!SymbolInfoTick(_Symbol,tk)) return;

   string ACCION = (d>0 ? "COMPRAR" : "VENDER");
   string BOTON  = (d>0 ? "Buy by Market" : "Sell by Market");
   double entrada= (d>0 ? tk.ask : tk.bid);
   double stop   = (d>0 ? sw-InpStopPadPts*_Point : sw+InpStopPadPts*_Point);
   if(d*(entrada-stop)<=0){ Print("Senal descartada: el precio ya paso el stop."); return; }
   double dist   = MathAbs(entrada-stop);
   double objetivo = entrada + d*dist*InpTargetR;

   //--- lotes sugeridos
   double bal = (InpBalanceFijo>0 ? InpBalanceFijo : AccountInfoDouble(ACCOUNT_BALANCE));
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(ts<=0||tv<=0){ ts=_Point; tv=ts*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); }
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vstp=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double perLot=(dist/ts)*tv;
   double riesgo=bal*InpRiskPct/100.0;
   double lotes = perLot>0 ? MathFloor((riesgo/perLot)/vstp)*vstp : 0;
   string notaLote="";
   if(lotes<vmin){ notaLote=" << MENOS QUE EL MINIMO, NO ALCANZA EL CAPITAL"; lotes=0; }
   double riesgoReal=lotes*perLot;

   gSenales++;
   gUltima=StringFormat("%s  %s  entrada %s  SL %s  TP %s  %.2f lotes",
            TimeToString(TimeCurrent(),TIME_MINUTES), ACCION,
            DoubleToString(entrada,_Digits), DoubleToString(stop,_Digits),
            DoubleToString(objetivo,_Digits), lotes);

   //--- panel grande
   Cartel(d,ACCION,BOTON,entrada,stop,objetivo,lotes,riesgoReal,dist);
   if(InpDibujar) Dibujar(d,b,i3,ref,sw,rj,entrada,stop,objetivo);

   string txt=StringFormat("%s  %s  |  entrada %s  SL %s  TP %s  |  %.2f lotes (riesgo $%.2f)%s",
              ACCION,_Symbol,DoubleToString(entrada,_Digits),DoubleToString(stop,_Digits),
              DoubleToString(objetivo,_Digits),lotes,riesgoReal,notaLote);
   if(InpPopup) Alert(txt);
   if(InpPush)  SendNotification(txt);
   Print(">>> ",txt);
  }

//====================================================================
void Lbl(const string n,const int x,const int y,const string t,
         const color c,const int sz=9,const string fnt="Consolas")
  {
   if(ObjectFind(0,n)<0 && !ObjectCreate(0,n,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,n,OBJPROP_TEXT,t);      ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetString (0,n,OBJPROP_FONT,fnt);    ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
  }

void Cartel(const int d,const string ACCION,const string BOTON,
            const double entrada,const double stop,const double objetivo,
            const double lotes,const double riesgo,const double dist)
  {
   color c = (d>0 ? C'0,200,120' : C'235,70,70');
   if(ObjectFind(0,PFX+"bg")<0 && ObjectCreate(0,PFX+"bg",OBJ_RECTANGLE_LABEL,0,0,0))
     { ObjectSetInteger(0,PFX+"bg",OBJPROP_XDISTANCE,14);
       ObjectSetInteger(0,PFX+"bg",OBJPROP_YDISTANCE,24);
       ObjectSetInteger(0,PFX+"bg",OBJPROP_XSIZE,430);
       ObjectSetInteger(0,PFX+"bg",OBJPROP_YSIZE,300);
       ObjectSetInteger(0,PFX+"bg",OBJPROP_BGCOLOR,C'12,16,24');
       ObjectSetInteger(0,PFX+"bg",OBJPROP_BORDER_TYPE,BORDER_FLAT); }
   ObjectSetInteger(0,PFX+"bg",OBJPROP_COLOR,c);

   int y=34; int L=26;
   Lbl(PFX+"a0",L,y, (d>0?"▲  "+ACCION:"▼  "+ACCION), c, 22, "Arial Black"); y+=34;
   Lbl(PFX+"a1",L,y, _Symbol+"  "+EnumToString((ENUM_TIMEFRAMES)_Period)+
                     "   senal #"+(string)gSenales, clrSilver); y+=22;
   Lbl(PFX+"a2",L,y,"────────────────────────────────────",clrDimGray); y+=18;
   Lbl(PFX+"a3",L,y,StringFormat("ENTRADA    %s   (a mercado, ahora)",
        DoubleToString(entrada,_Digits)), clrWhite,10); y+=18;
   Lbl(PFX+"a4",L,y,StringFormat("STOP LOSS  %s   (%.0f puntos)",
        DoubleToString(stop,_Digits), dist/_Point), C'255,120,120',10); y+=18;
   Lbl(PFX+"a5",L,y,StringFormat("TAKE PROFIT %s  (%.0f puntos, %.1fR)",
        DoubleToString(objetivo,_Digits), dist*InpTargetR/_Point, InpTargetR),
        C'120,255,170',10); y+=18;
   Lbl(PFX+"a6",L,y,StringFormat("VOLUMEN    %.2f lotes   riesgo $%.2f",
        lotes, riesgo), clrGold,10); y+=24;
   Lbl(PFX+"a7",L,y,"COMO EJECUTARLO A MANO",clrWhite,10,"Arial Black"); y+=20;
   Lbl(PFX+"a8", L,y,"1.  Apreta  F9   (Nueva Orden)",clrSilver); y+=16;
   Lbl(PFX+"a9", L,y,StringFormat("2.  Volumen:      %.2f",lotes),clrSilver); y+=16;
   Lbl(PFX+"a10",L,y,StringFormat("3.  Stop Loss:    %s",DoubleToString(stop,_Digits)),clrSilver); y+=16;
   Lbl(PFX+"a11",L,y,StringFormat("4.  Take Profit:  %s",DoubleToString(objetivo,_Digits)),clrSilver); y+=16;
   Lbl(PFX+"a12",L,y,"5.  Clic en  \""+BOTON+"\"",c,10,"Arial Black"); y+=24;
   Lbl(PFX+"a13",L,y,"SIN RENTABILIDAD DEMOSTRADA - PF 0.80 medido",C'255,180,60',8); y+=14;
   Lbl(PFX+"a14",L,y,"Este panel NO opera. Vos decidis y vos ejecutas.",clrGray,8);
  }

void Panel()
  {
   Lbl(PFX+"st",14,340,"E-MT5-020 - solo deteccion, no opera   |   ultima: "+gUltima,
       clrDimGray,8);
  }

//====================================================================
void Dibujar(const int d,const Bar &b[],const int i3,const double ref,
             const double sw,const double rj,const double entrada,
             const double stop,const double objetivo)
  {
   string n=PFX+"s"+(string)gSenales;
   int ps=PeriodSeconds(); datetime t0=b[i3-2].t, t1=b[i3].t+ps*12;
   color c=(d>0?C'0,200,120':C'235,70,70');
   Linea(n+"_e",t0,entrada,t1,entrada,c,STYLE_SOLID,2);
   Linea(n+"_s",t0,stop,   t1,stop,   clrRed,  STYLE_DOT,1);
   Linea(n+"_t",t0,objetivo,t1,objetivo,clrLime,STYLE_DOT,1);
   Texto(n+"_1",b[i3-2].t,ref,"1",clrDeepSkyBlue);
   Texto(n+"_2",b[i3-1].t,sw, "2",clrOrange);
   Texto(n+"_3",b[i3].t,  rj, "3",clrLime);
  }

void Linea(const string n,const datetime t1,const double p1,
           const datetime t2,const double p2,const color c,
           const int style,const int w)
  {
   if(!ObjectCreate(0,n,OBJ_TREND,0,t1,p1,t2,p2)) return;
   ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_STYLE,style);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,w); ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
  }

void Texto(const string n,const datetime t,const double p,const string s,const color c)
  {
   if(!ObjectCreate(0,n,OBJ_TEXT,0,t,p)) return;
   ObjectSetString(0,n,OBJPROP_TEXT,s); ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Black"); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
  }
//+------------------------------------------------------------------+
