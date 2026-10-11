"""Minimal HTTP listener for BackgroundUploadTest (not part of the product).

usage: python3 background_listener.py PORTFILE OUTPREFIX

Binds 127.0.0.1 on a free port, writes the port number to PORTFILE, serves one POST,
writes the raw body to OUTPREFIX.body and then the request headers (one "name: value"
line each) to OUTPREFIX.hdr, replies with {"status":"ok"} and exits. The .hdr file is
written last, so its existence means the request has been fully recorded.
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = self.headers.get("Content-Length")
        # A chunked request has no Content-Length; the body is then left unread and the
        # test sees the missing header.
        body = self.rfile.read(int(length)) if length is not None else b""
        with open(self.server.prefix + ".body", "wb") as fh:
            fh.write(body)
        tmp = self.server.prefix + ".hdr.tmp"
        with open(tmp, "w") as fh:
            for name, value in self.headers.items():
                fh.write("%s: %s\n" % (name.lower(), value))
        os.rename(tmp, self.server.prefix + ".hdr")
        reply = json.dumps({"status": "ok"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(reply)))
        self.end_headers()
        self.wfile.write(reply)

    def log_message(self, *args):
        pass


def main(portfile, prefix):
    server = HTTPServer(("127.0.0.1", 0), Handler)
    server.prefix = prefix
    with open(portfile + ".tmp", "w") as fh:
        fh.write(str(server.server_port))
    os.rename(portfile + ".tmp", portfile)
    server.timeout = 30
    server.handle_request()


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
