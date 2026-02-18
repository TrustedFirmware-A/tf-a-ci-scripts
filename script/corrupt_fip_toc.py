#!/usr/bin/env python3
import argparse
import struct
import sys

HEADER_SIZE = 16
ENTRY_SIZE = 40
UUID_SIZE = 16
# offset is decided in such a way that it enters in SRAM region Flash
# base (0x08000000) + OFFSET truncates to 0x04000000
OFFSET = 0xFC000000
ERROR_EXIT = 1

# UUID_TRUSTED_BOOT_FIRMWARE_BL2 from TF-A firmware_image_package.h
BL2_UUID = bytes(
    [
        0x5F,
        0xF9,
        0xEC,
        0x0B,
        0x4D,
        0x22,
        0x3E,
        0x4D,
        0xA5,
        0x44,
        0xC3,
        0x9D,
        0x81,
        0xC7,
        0x3F,
        0x0A,
    ]
)


def read_file(path):
    with open(path, "rb") as f:
        return f.read()


def write_file(path, data):
    with open(path, "wb") as f:
        f.write(data)


def parse_uuid_bytes(text):
    if text is None:
        return None
    hex_text = "".join(ch for ch in text if ch in "0123456789abcdefABCDEF")
    if len(hex_text) != 32:
        return None
    return bytes.fromhex(hex_text)


def parse_int(text):
    return int(text, 0)


def find_entry(data, target_uuid=None):
    off = HEADER_SIZE
    while off + ENTRY_SIZE <= len(data):
        uuid = data[off : off + UUID_SIZE]
        if uuid == b"\x00" * UUID_SIZE:
            return None
        offset_address, size, flags = struct.unpack_from("<QQQ", data, off + UUID_SIZE)
        if (target_uuid is None) or (uuid == target_uuid):
            return off, uuid, offset_address, size, flags
        off += ENTRY_SIZE
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument(
        "--mode",
        default="bad_offset_size",
        choices=["bad_offset_size", "bad_offset", "oob_size"],
    )
    ap.add_argument("--output")
    ap.add_argument(
        "--target",
        default="bl2",
        choices=["bl2", "first", "uuid"],
        help="Select which ToC entry to corrupt",
    )
    ap.add_argument("--uuid", help="UUID for --target uuid (hex, with or without dashes)")
    ap.add_argument(
        "--corrupt-offset",
        type=parse_int,
        default=None,
        help="Corrupt ToC entry offset (default: 0xFC000000)",
    )
    ap.add_argument(
        "--corrupt-len",
        type=parse_int,
        default=None,
        help="Corrupt ToC entry length (default: len(input) + 0x1000)",
    )
    args = ap.parse_args()

    data = read_file(args.input)
    if len(data) < HEADER_SIZE + ENTRY_SIZE:
        print("input fip too small", file=sys.stderr)
        return ERROR_EXIT

    if args.target == "bl2":
        target_uuid = BL2_UUID
    elif args.target == "uuid":
        target_uuid = parse_uuid_bytes(args.uuid)
        if target_uuid is None:
            print("invalid --uuid; expected 16-byte hex UUID", file=sys.stderr)
            return ERROR_EXIT
    else:
        target_uuid = None

    entry = find_entry(data, target_uuid=target_uuid)
    if entry is None:
        print("no matching toc entry found", file=sys.stderr)
        return ERROR_EXIT

    entry_off, _uuid, offset_address, size, flags = entry
    new_size = args.corrupt_len if args.corrupt_len is not None else len(data) + 0x1000
    new_offset = (
        args.corrupt_offset if args.corrupt_offset is not None else OFFSET
    )

    if args.mode == "bad_offset_size":
        offset_address = new_offset
        size = new_size
    elif args.mode == "bad_offset":
        offset_address = new_offset
    elif args.mode == "oob_size":
        size = new_size

    bad = bytearray(data)
    struct.pack_into("<QQQ", bad, entry_off + UUID_SIZE, offset_address, size, flags)

    out_path = args.output or args.input
    write_file(out_path, bad)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
