#!/usr/bin/env python3
"""
ZhiMind 模拟服务器 (Mock Server)
用于在开发环境下模拟社区插件市场或 LLM 远程接口。
"""

import http.server
import socketserver
import os

PORT = 8080
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class MockHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        # 默认重定向 /api/community 到 community.json
        if self.path == "/api/community":
            self.path = "/community.json"
        return super().do_GET()

if __name__ == "__main__":
    print(f"🚀 ZhiMind Mock Server 启动在: http://localhost:{PORT}")
    print(f"📂 根目录: {DIRECTORY}")
    with socketserver.TCPServer(("", PORT), MockHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n🛑 服务器已停止")
            httpd.server_close()
