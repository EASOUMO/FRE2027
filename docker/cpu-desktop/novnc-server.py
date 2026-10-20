#!/usr/bin/env python3
"""websockify serving noVNC, with `Cache-Control: no-store` on every reply.

Without that header, browsers keep the noVNC page and reuse it without asking
the server, so they would keep showing it after you switch this address to
the GPU setup. Arguments are passed on to websockify.
"""
import http.server
import sys

from websockify import websocketproxy

_end_headers = http.server.BaseHTTPRequestHandler.end_headers


def end_headers(self):
    self.send_header('Cache-Control', 'no-store')
    _end_headers(self)


http.server.BaseHTTPRequestHandler.end_headers = end_headers

sys.argv[0] = 'websockify'
websocketproxy.websockify_init()
