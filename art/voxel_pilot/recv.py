# Receives part dumps from Studio's command bar (local only) into src/.
import http.server, sys, os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src")
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers["Content-Length"]); b = self.rfile.read(n)
        open(os.path.join(OUT, self.path.strip("/") + ".json"), "wb").write(b)
        print("got", self.path, n, flush=True)
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
    def log_message(self, *a): pass
http.server.HTTPServer(("127.0.0.1", 8791), H).serve_forever()
