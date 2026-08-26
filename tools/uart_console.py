#!/usr/bin/env python3
import argparse
import datetime
from pathlib import Path

import serial


def timestamp():
    return datetime.datetime.now().isoformat(timespec="milliseconds")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True)
    parser.add_argument("--raw", required=True)
    parser.add_argument("--log", required=True)
    args = parser.parse_args()

    raw_path = Path(args.raw)
    log_path = Path(args.log)

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
        header = f"UART: {args.port}\nConfiguration: 115200 8N1\nStarted: {timestamp()}\n\n"
        log_file.write(header)
        log_file.flush()
        print(header, end="", flush=True)
        print("Live monitoring. Press Ctrl+C in this window to stop.", flush=True)

        try:
            while True:
                data = port.read(4096)
                if not data:
                    continue
                raw_file.write(data)
                raw_file.flush()
                text = data.decode("utf-8", errors="replace")
                entry = f"[{timestamp()}] {text}"
                log_file.write(entry)
                log_file.flush()
                print(text, end="", flush=True)
        except KeyboardInterrupt:
            log_file.write(f"\nStopped: {timestamp()}\n")
            log_file.flush()


if __name__ == "__main__":
    main()
