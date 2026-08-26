# Tools

## QCN6122 BDF Conversion

`convert-qcn6122-bdf-2.7.py` converts the expected OEM QCN6122 `bdwlan.b60`
into the form used by the matched OpenWrt ath11k firmware. It validates exact
input/output hashes and refuses unknown data.

```sh
python3 tools/convert-qcn6122-bdf-2.7.py input-bdwlan.b60 output-bdwlan.b60
```

## UART Helpers

`uart_console.py` records raw and timestamped UART output. `uart_send.py` sends
one command and records the response. Both require Python and `pyserial`.

These helpers must not be used concurrently on the same COM port. Raw captures
and text logs can contain private device information and are ignored by Git.
