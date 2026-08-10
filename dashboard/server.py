#!/usr/bin/env python3
"""
PROJECT TRADER — live dashboard.

Reads the state file that TRADER-ALERT-001 writes every second inside the MT5
sandbox and serves it as a large, high-contrast page. Exists because the MT5
chart panel renders inside Wine, where its legibility cannot be verified.

No trading, no orders, read-only.
"""
import http.server, json, os, re, socketserver, threading

W = os.path.expanduser(
    "~/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/users/"
    "nachogm/AppData/Roaming/MetaQuotes/Terminal/Common/Files")
STATE = os.path.join(W, "TRADER-ALERT-001-state.txt")
ALERTS = os.path.join(W, "TRADER-ALERT-001-live.csv")
PORT = 8791


def parse_state():
    d = {}
    try:
        with open(STATE, "r", errors="replace") as fh:
            for line in fh:
                m = re.match(r"^(\S+)\s+(.*)$", line.rstrip("\n"))
                if m:
                    d[m.group(1)] = m.group(2).strip()
    except FileNotFoundError:
        pass
    return d


def parse_alerts(n=8):
    out = []
    try:
        with open(ALERTS, "r", errors="replace") as fh:
            for line in fh:
                p = [x.strip() for x in line.split(",")]
                if len(p) >= 7:
                    out.append(dict(t=p[0], sym=p[1], dir=p[2], lvl=p[3],
                                    sl=p[4], tp=p[5], stat=p[6]))
    except FileNotFoundError:
        pass
    return out[-n:][::-1]


def candles():
    """velas_M5 line -> list of (mark, pips)"""
    raw = parse_state().get("velas_M5", "")
    out = []
    for tok in raw.split():
        m = re.match(r"^([SB=])([+-][\d.]+)$", tok)
        if m:
            out.append((m.group(1), float(m.group(2))))
    return out


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path.startswith("/api"):
            body = json.dumps(dict(state=parse_state(), alerts=parse_alerts(),
                                   candles=candles())).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        body = PAGE.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


PAGE = r"""<!doctype html><html lang="es"><head><meta charset="utf-8">
<title>PROJECT TRADER</title>
<style>
:root{font-size:16px}
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0d0f14;color:#e8ecf2;font-family:-apple-system,"Segoe UI",Arial,sans-serif;
     padding:1.5rem;font-size:1.0rem;line-height:1.45}
.wrap{max-width:1100px;margin:0 auto;display:grid;gap:1.1rem;
      grid-template-columns:repeat(auto-fit,minmax(330px,1fr))}
@media(max-width:760px){.wrap{grid-template-columns:1fr}body{padding:1rem}}
.card{background:#161a22;border:1px solid #2a3140;border-radius:.6rem;padding:1.1rem 1.3rem}
.full{grid-column:1/-1}
h2{font-size:1.0rem;letter-spacing:.08em;text-transform:uppercase;color:#7d8798;
   margin-bottom:.7rem;font-weight:700}
.price{font-size:1.5rem;font-weight:800;line-height:1.2;font-variant-numeric:tabular-nums}
.sub{font-size:1.0rem;color:#93a0b4;margin-top:.25rem}
.dir{font-size:1.5rem;font-weight:800;line-height:1.2}
.up{color:#3ddc84}.down{color:#ff5a5a}.flat{color:#9aa4b5}
.row{display:flex;justify-content:space-between;align-items:baseline;gap:.8rem;
     flex-wrap:wrap;padding:.45rem 0;border-bottom:1px solid #232a36;font-size:1.1rem}
.row:last-child{border:0}
.k{color:#93a0b4}.v{font-weight:700;font-variant-numeric:tabular-nums}
.armed{color:#4fc3ff;font-weight:800}.wait{color:#6b7382}
.candle{display:flex;justify-content:space-between;padding:.4rem 0;
        border-bottom:1px solid #232a36;font-size:1.15rem;font-weight:700;
        font-variant-numeric:tabular-nums}
.warn{background:#2a1013;border-color:#7a2a2f}
.warn .big{font-size:1.25rem;font-weight:800;color:#ff5a5a;margin-bottom:.5rem}
.warn .line{font-size:1.05rem;color:#e0a8ac;padding:.15rem 0;font-variant-numeric:tabular-nums}
.alert{font-size:1.1rem;padding:.5rem 0;border-bottom:1px solid #232a36;
       font-variant-numeric:tabular-nums}
.none{color:#6b7382;font-size:1.05rem;padding:.5rem 0}
.stale{color:#ffb347;font-size:1.0rem;margin-top:.5rem}
</style></head><body>
<div class="wrap">

  <div class="card">
    <h2>Precio</h2>
    <div class="price" id="price">—</div>
    <div class="sub" id="sym">—</div>
    <div class="sub" id="spread">—</div>
    <div class="stale" id="stale"></div>
  </div>

  <div class="card">
    <h2>Movimiento actual</h2>
    <div class="dir flat" id="dir">—</div>
    <div class="sub" id="mov">—</div>
  </div>

  <div class="card">
    <h2>Niveles focales</h2>
    <div class="row"><span class="k" id="lupk">arriba</span><span class="v" id="lup">—</span></div>
    <div class="row"><span class="k" id="ldnk">abajo</span><span class="v" id="ldn">—</span></div>
    <div class="row"><span class="k">ticks recibidos</span><span class="v" id="ticks">—</span></div>
  </div>

  <div class="card">
    <h2>Vela por vela (M5)</h2>
    <div id="candles"></div>
  </div>

  <div class="card warn full">
    <div class="big" id="verdict">FIABILIDAD MEDIDA DE LA ALERTA</div>
    <div class="line">senal focal &nbsp; 28.90 %&nbsp;&nbsp; (n=872, GBPUSD virgen)</div>
    <div class="line">entrada azar &nbsp; 31.81 %&nbsp;&nbsp; &larr; el nulo real</div>
    <div class="line">break-even &nbsp;&nbsp;&nbsp; 33.33 %&nbsp;&nbsp; (payoff 2R)</div>
    <div class="line" style="margin-top:10px;color:#ff5a5a;font-weight:800;font-size:1.35rem">
      POR DEBAJO DEL AZAR &mdash; NO OPERABLE</div>
  </div>

  <div class="card full">
    <h2>Alertas</h2>
    <div id="alerts"><div class="none">sin alertas todavia</div></div>
  </div>

</div>
<script>
async function tick(){
  try{
    const r = await fetch('/api',{cache:'no-store'});
    const d = await r.json();
    const s = d.state || {};

    document.getElementById('price').textContent = (s.precio||'—').split(/\s+/)[0];
    document.getElementById('sym').textContent   = s.simbolo || '—';
    const sp = (s.precio||'').match(/spread\s+([\d.]+)/);
    document.getElementById('spread').textContent = sp ? ('spread '+sp[1]+' pips') : '';

    const mv = (s.movimiento||'').split(/\s+/);
    const dir = mv[0]||'—';
    const el = document.getElementById('dir');
    el.textContent = dir;
    el.className = 'dir ' + (dir==='SUBIENDO'?'up':dir==='BAJANDO'?'down':'flat');
    document.getElementById('mov').textContent = mv.slice(1).join(' ');

    function lvl(id,key){
      const raw = s[key]||'';
      const armed = /ARMADO/.test(raw);
      const e = document.getElementById(id);
      e.textContent = raw.replace('ARMADO','').replace('esperando','').trim();
      e.className = 'v ' + (armed?'armed':'wait');
      const k = document.getElementById(id+'k');
      k.textContent = (id==='lup'?'arriba  ':'abajo  ') + (armed?'ARMADO':'esperando');
      k.className = 'k ' + (armed?'armed':'wait');
    }
    lvl('lup','nivel_arriba'); lvl('ldn','nivel_abajo');
    document.getElementById('ticks').textContent = s.ticks || '—';

    const cs = d.candles||[];
    document.getElementById('candles').innerHTML = cs.length
      ? cs.map(c=>{
          const up = c[0]==='S', dn = c[0]==='B';
          const cls = up?'up':dn?'down':'flat';
          const lbl = up?'SUBE':dn?'BAJA':'IGUAL';
          return `<div class="candle"><span class="${cls}">${lbl}</span>`+
                 `<span class="${cls}">${c[1]>0?'+':''}${c[1].toFixed(1)} pips</span></div>`;
        }).join('')
      : '<div class="none">esperando velas…</div>';

    const al = d.alerts||[];
    document.getElementById('alerts').innerHTML = al.length
      ? al.map(a=>`<div class="alert"><b class="${a.dir==='SUBE'?'up':'down'}">${a.dir}</b>`+
          ` &nbsp; ${a.t} &nbsp; nivel ${a.lvl} &nbsp; stop ${a.sl} &nbsp; objetivo ${a.tp}`+
          ` &nbsp; <span style="color:#ff8080">fiabilidad ${a.stat}%</span></div>`).join('')
      : '<div class="none">sin alertas todavia</div>';

    document.getElementById('stale').textContent = s.hora ? ('actualizado '+s.hora) : 'sin datos del EA';
  }catch(e){
    document.getElementById('stale').textContent = 'sin conexion con el lector';
  }
}
tick(); setInterval(tick, 1000);
</script></body></html>"""


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), H) as httpd:
        print(f"dashboard en http://127.0.0.1:{PORT}")
        httpd.serve_forever()
