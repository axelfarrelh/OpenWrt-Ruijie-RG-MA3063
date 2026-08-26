#!/usr/bin/env python3
import argparse
import datetime
from pathlib import Path
import time

import serial


def timestamp():
    return datetime.datetime.now().isoformat(timespec="milliseconds")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True)
    parser.add_argument("--command", required=True)
    parser.add_argument("--raw", required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--wait", type=float, default=20)
    args = parser.parse_args()

    raw_path = Path(args.raw)
    log_path = Path(args.log)
    command = f"{args.command}\r\n".encode("ascii")

    with serial.Serial(
        args.port,
        baudrate=115200,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0.2,
        xonxoff=False,
        rtscts=False,
        dsrdtr=False,
    ) as port, raw_path.open("ab") as raw_file, log_path.open(
        "a", encoding="utf-8", errors="replace"
    ) as log_file:
        port.reset_input_buffer()
        log_file.write(
            f"UART: {args.port}\nConfiguration: 115200 8N1\n"
            f"Started: {timestamp()}\nCommand: {args.command}\n\n"
        )
        port.write(command)
        port.flush()

        deadline = time.monotonic() + args.wait
        while time.monotonic() < deadline:
            data = port.read(4096)
            if not data:
                continue
            raw_file.write(data)
            raw_file.flush()
            log_file.write(f"[{timestamp()}] {data.decode('utf-8', errors='replace')}")
            log_file.flush()

        log_file.write(f"\nStopped: {timestamp()}\n")

    print(f"UART command completed: {args.command}")
    print(f"Raw capture: {raw_path}")
    print(f"Text log: {log_path}")


if __name__ == "__main__":
    main()
