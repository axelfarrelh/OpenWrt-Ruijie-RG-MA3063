# Wi-Fi and Ethernet Findings

## Wi-Fi

Both radios initialize with the OpenWrt
`ath11k-firmware-ipq5018-qcn6122` package. Device-specific BDF and ART
calibration are layered on top; OEM executable Q6/M3 firmware is not copied
into OpenWrt.

Expected installed board-data hashes:

```text
IPQ5018 board.bin:
e0eea9f4f7517c4360f03e91e83bd142c830e9d10ac5d46bfe9652db51880832

QCN6122 board.bin:
f6f905994c74a81daaa6e5186a6463aa89dd3184819d82be2c8fc554286ea254
```

The QCN6122 conversion changes the OEM BDF mode byte and recomputes its
checksum. `tools/convert-qcn6122-bdf-2.7.py` validates both input and output.

## QCA8337 MDIO Timing

At the default `/8` divider, MDIO1 returned deterministic corrupt identities:

```text
switch register 0: 0x00000981
PHY ID:            0x00044012
```

The board-scoped `/64` override produced the OEM-matching values:

```text
switch register 0: 0x00001302
PHY ID:            0x004dd036
```

No fake ID or driver acceptance workaround is used.

## Driver Ownership

The mainline qca8k DSA driver owns the QCA8337. QCA SSDK remains installed only
because the IPQ5018 NSS dataplane requires its symbols; external ISISC support
is disabled so both drivers do not claim the switch.

## Validation

All four chassis sockets passed carrier and IPv4 traffic tests. Both radios
loaded firmware and calibration and passed client traffic in RAM boot. The same
drivers initialize after persistent cold boot.
