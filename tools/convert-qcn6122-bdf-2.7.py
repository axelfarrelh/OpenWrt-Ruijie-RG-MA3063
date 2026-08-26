#!/usr/bin/env python3
import hashlib
import sys
from pathlib import Path

SOURCE_SHA256 = "ead4f8d49febf004bafa043106698737bc129706a6ec1395dbd8036d63d4c36c"
OUTPUT_SHA256 = "f6f905994c74a81daaa6e5186a6463aa89dd3184819d82be2c8fc554286ea254"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <OEM-bdwlan.b60> <output>", file=sys.stderr)
        return 2

    source = Path(sys.argv[1])
    output = Path(sys.argv[2])
    original = source.read_bytes()

    if len(original) != 0x20000 or sha256(original) != SOURCE_SHA256:
        raise SystemExit("Refusing unexpected QCN6122 OEM BDF input")
    if original[:4] != bytes.fromhex("01 00 04 04") or original[0x45C] != 0x03:
        raise SystemExit("Unexpected QCN6122 BDF structure")

    converted = bytearray(original)
    converted[0x45C] = 0
    converted[0x0A:0x0C] = b"\0\0"

    checksum = 0
    for offset in range(0, len(converted), 2):
        checksum ^= converted[offset] | (converted[offset + 1] << 8)
    converted[0x0A:0x0C] = (checksum ^ 0xFFFF).to_bytes(2, "little")

    result = bytes(converted)
    differences = [i for i, pair in enumerate(zip(original, result)) if pair[0] != pair[1]]
    if differences != [0x0A, 0x45C] or sha256(result) != OUTPUT_SHA256:
        raise SystemExit("Generated QCN6122 BDF failed provenance checks")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(result)
    print(f"Generated {output}: {OUTPUT_SHA256}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
