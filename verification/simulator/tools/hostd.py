#!/usr/bin/env python3
"""
hostd.py — dmctp host filesystem daemon
Serves the kernel's /host mount point over UART.

usage: python3 tools/hostd.py <serial_port> [root_dir]
  port:     /dev/ttyUSB0 or COM3 etc.
  root_dir: directory to expose as /host  (default: ./hostroot)

example:
  mkdir hostroot
  echo "hello from host" > hostroot/hello.txt
  python3 tools/hostd.py /dev/ttyUSB0 ./hostroot
"""

import sys
import os
import struct
import threading

MAGIC = 0x02   # STX

def read_until_magic(ser):
    while True:
        b = ser.read(1)
        if not b: raise EOFError("EOF on UART stream")
        if b[0] == MAGIC:
            return
        # transparently print kernel output to host stdout
        sys.stdout.buffer.write(b)
        sys.stdout.buffer.flush()

def forward_stdin(ser):
    while True:
        b = sys.stdin.buffer.read(1)
        if b:
            try:
                ser.write(b)
            except BrokenPipeError:
                break

def read_line(ser):
    buf = b""
    while True:
        c = ser.read(1)
        if not c: raise EOFError("EOF on UART stream")
        if c == b'\n': break
        buf += c
    return buf.decode(errors='replace').strip()

def send_frame(ser, data: bytes):
    ser.write(bytes([MAGIC]) + data)

def handle_ping(ser, _path, root):
    send_frame(ser, b"PONG\n")

def handle_read(ser, path, root):
    full = os.path.join(root, path.lstrip("/"))
    try:
        with open(full, "rb") as f:
            data = f.read()  # read entire file
        size = struct.pack("<I", len(data))
        send_frame(ser, size + data)
    except Exception as e:
        print(f"  READ error: {e}")
        send_frame(ser, struct.pack("<I", 0))

def handle_write(ser, path, root):
    parts = path.rsplit(" ", 1)
    if len(parts) == 2:
        path = parts[0]
        size = int(parts[1])
    else:
        size = 0
    data = ser.read(size)
    full = os.path.join(root, path.lstrip("/"))
    try:
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "wb") as f:
            f.write(data)
        send_frame(ser, b"OK\n")
    except Exception as e:
        print(f"  WRITE error: {e}")
        send_frame(ser, b"ERR\n")

def handle_ls(ser, path, root):
    full = os.path.join(root, path.lstrip("/"))
    try:
        entries = os.listdir(full)
        for e in entries:
            fp = os.path.join(full, e)
            tag = "/" if os.path.isdir(fp) else ""
            send_frame(ser, f"{e}{tag}\n".encode())
    except Exception as e:
        print(f"  LS error: {e}")
    send_frame(ser, b"END\n")

def handle_mkdir(ser, path, root):
    full = os.path.join(root, path.lstrip("/"))
    try:
        os.makedirs(full, exist_ok=True)
        send_frame(ser, b"OK\n")
    except Exception as e:
        print(f"  MKDIR error: {e}")
        send_frame(ser, b"ERR\n")

def handle_rm(ser, path, root):
    full = os.path.join(root, path.lstrip("/"))
    try:
        if os.path.isdir(full):
            import shutil
            shutil.rmtree(full)
        else:
            os.remove(full)
        send_frame(ser, b"OK\n")
    except Exception as e:
        print(f"  RM error: {e}")
        send_frame(ser, b"ERR\n")

def handle_stat(ser, path, root):
    full = os.path.join(root, path.lstrip("/"))
    try:
        st = os.stat(full)
        # return size and type (D for dir, F for file)
        ftype = "D" if os.path.isdir(full) else "F"
        send_frame(ser, f"{ftype} {st.st_size}\n".encode())
    except Exception as e:
        # File not found or error
        send_frame(ser, b"ERR\n")

HANDLERS = {
    "HOST_PING":  handle_ping,
    "HOST_READ":  handle_read,
    "HOST_WRITE": handle_write,
    "HOST_LS":    handle_ls,
    "HOST_MKDIR": handle_mkdir,
    "HOST_RM":    handle_rm,
    "HOST_STAT":  handle_stat,
}

def serve(root, cmd):
    import shlex
    import subprocess
    import os
    if isinstance(cmd, str):
        args = shlex.split(cmd)
    else:
        args = cmd

    stdout_log = None
    if "--stdout-log" in args:
        idx = args.index("--stdout-log")
        stdout_log = args[idx+1]
        args.pop(idx)
        args.pop(idx)

    r, w = os.pipe()
    os.set_inheritable(w, True)

    env = os.environ.copy()
    env["UART_TX_FD"] = str(w)

    print(f"[hostd] serving {root!r} running {args}")
    stdout_target = open(stdout_log, "wb") if stdout_log else sys.stdout
    proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=stdout_target, stderr=subprocess.STDOUT, env=env, pass_fds=(w,), bufsize=0)
    
    os.close(w)
    uart_fd = os.fdopen(r, "rb", buffering=0)

    class ProcessIO:
        def read(self, n):
            data = b''
            while len(data) < n:
                chunk = uart_fd.read(n - len(data))
                if not chunk:
                    break
                data += chunk
            return data
        def write(self, b):
            proc.stdin.write(b)
            proc.stdin.flush()

    ser = ProcessIO()

    threading.Thread(target=forward_stdin, args=(ser,), daemon=True).start()

    try:
        while True:
            read_until_magic(ser)
            line = read_line(ser)
            if not line: continue

            parts = line.split(" ", 1)
            cmd_name   = parts[0]
            path  = parts[1] if len(parts) > 1 else "/"

            if cmd_name in HANDLERS:
                HANDLERS[cmd_name](ser, path, root)
            else:
                sys.stdout.buffer.write(f"[kernel] {line}\n".encode())
                sys.stdout.buffer.flush()

            if proc.poll() is not None:
                break
    except KeyboardInterrupt:
        pass
    except Exception as e:
        print(f"[hostd] error: {e}")
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
        os._exit(0) # Forcefully exit to avoid daemon thread deadlock on sys.stdin

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("usage: hostd.py <root_dir> <cmd...>")
        sys.exit(1)
    
    root = sys.argv[1]
    cmd = " ".join(sys.argv[2:])
    os.makedirs(root, exist_ok=True)
    
    # put stdin into raw mode so we can forward characters immediately
    import tty
    import termios
    import fcntl
    if sys.stdin.isatty():
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            fcntl.fcntl(fd, fcntl.F_SETFL, os.O_NONBLOCK)
            serve(root, cmd)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    else:
        serve(root, cmd)
