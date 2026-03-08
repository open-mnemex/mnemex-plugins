#!/usr/bin/env python3
"""
Chrome Bookmarks Native Messaging Host

Bridges between Chrome extension (via stdin/stdout native messaging protocol)
and CLI clients (via Unix socket at /tmp/chrome-bookmarks.sock).
"""

import asyncio
import json
import os
import struct
import sys

SOCKET_PATH = "/tmp/chrome-bookmarks.sock"


class NativeMessagingHost:
    def __init__(self):
        self.pending_requests = {}  # id -> Future
        self.next_id = 1
        self.stdin_reader = None
        self.stdout_writer = None
        self.read_buffer = b""

    async def start(self):
        # Clean up stale socket
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)

        # Set up stdin/stdout for native messaging (binary mode)
        loop = asyncio.get_event_loop()
        self.stdin_reader = asyncio.StreamReader()
        transport, _ = await loop.connect_read_pipe(
            lambda: asyncio.StreamReaderProtocol(self.stdin_reader),
            sys.stdin.buffer,
        )

        # stdout needs raw binary writes
        self.stdout_fd = sys.stdout.buffer

        # Start socket server
        server = await asyncio.start_unix_server(
            self.handle_client, path=SOCKET_PATH
        )
        os.chmod(SOCKET_PATH, 0o600)

        log("Host started, listening on", SOCKET_PATH)

        # Read from stdin (extension responses) in background
        stdin_task = asyncio.create_task(self.read_stdin_loop())

        try:
            await server.serve_forever()
        except asyncio.CancelledError:
            pass
        finally:
            stdin_task.cancel()
            server.close()
            if os.path.exists(SOCKET_PATH):
                os.unlink(SOCKET_PATH)

    async def read_stdin_loop(self):
        """Read native messaging responses from Chrome extension."""
        try:
            while True:
                # Read 4-byte length prefix
                raw_length = await self.stdin_reader.readexactly(4)
                length = struct.unpack("<I", raw_length)[0]

                if length > 1024 * 1024:  # 1MB safety limit
                    log("Message too large:", length)
                    continue

                raw_msg = await self.stdin_reader.readexactly(length)
                msg = json.loads(raw_msg.decode("utf-8"))

                req_id = msg.get("id")
                if req_id and req_id in self.pending_requests:
                    future = self.pending_requests.pop(req_id)
                    if not future.done():
                        future.set_result(msg)
                else:
                    log("Unmatched response:", msg)

        except asyncio.IncompleteReadError:
            log("Extension disconnected (stdin EOF)")
            # Extension closed, exit
            asyncio.get_event_loop().stop()
        except asyncio.CancelledError:
            pass
        except Exception as e:
            log("stdin read error:", e)

    def send_to_extension(self, msg):
        """Send a message to Chrome extension via stdout."""
        data = json.dumps(msg).encode("utf-8")
        length = struct.pack("<I", len(data))
        self.stdout_fd.write(length + data)
        self.stdout_fd.flush()

    async def send_command(self, command, args=None, timeout=10):
        """Send command to extension and wait for response."""
        req_id = str(self.next_id)
        self.next_id += 1

        future = asyncio.get_event_loop().create_future()
        self.pending_requests[req_id] = future

        msg = {"id": req_id, "command": command}
        if args:
            msg["args"] = args

        self.send_to_extension(msg)

        try:
            result = await asyncio.wait_for(future, timeout=timeout)
            return result
        except asyncio.TimeoutError:
            self.pending_requests.pop(req_id, None)
            return {"id": req_id, "success": False, "error": "Request timed out"}

    async def handle_client(self, reader, writer):
        """Handle a CLI client connection on the Unix socket."""
        try:
            data = await asyncio.wait_for(reader.read(65536), timeout=15)
            if not data:
                return

            request = json.loads(data.decode("utf-8"))
            command = request.get("command")
            args = request.get("args", {})

            log("CLI request:", command, args)

            result = await self.send_command(command, args)

            response = json.dumps(result).encode("utf-8")
            writer.write(response)
            await writer.drain()

        except asyncio.TimeoutError:
            error = json.dumps({"success": False, "error": "Timeout"}).encode("utf-8")
            writer.write(error)
            await writer.drain()
        except Exception as e:
            log("Client error:", e)
            try:
                error = json.dumps(
                    {"success": False, "error": str(e)}
                ).encode("utf-8")
                writer.write(error)
                await writer.drain()
            except Exception:
                pass
        finally:
            writer.close()
            try:
                await writer.wait_closed()
            except Exception:
                pass


def log(*args):
    """Log to stderr (visible in Chrome's native messaging log)."""
    print("[chrome-bookmarks-host]", *args, file=sys.stderr, flush=True)


if __name__ == "__main__":
    host = NativeMessagingHost()
    try:
        asyncio.run(host.start())
    except KeyboardInterrupt:
        pass
