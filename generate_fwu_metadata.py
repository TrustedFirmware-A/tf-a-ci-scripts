#!/usr/bin/env python3
# Copyright (c) 2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
# Generate FWU metadata Version 1.

import argparse
import uuid
import zlib
import os
import ast

def gen_fwu_metadata(metadata_file, image_data):
    def add_field_to_metadata(value):
        # Write the integer values to file in little endian representation
        with open(metadata_file, "ab") as fp:
            fp.write(value.to_bytes(4, byteorder='little'))

    def add_uuid_to_metadata(uuid_str):
        # Validate UUID string and write to file in little endian representation
        uuid_val = uuid.UUID(uuid_str)
        with open(metadata_file, "ab") as fp:
            fp.write(uuid_val.bytes_le)

    # Delete the metadata_file if it exists
    if os.path.exists(metadata_file):
        os.remove(metadata_file)

    # Fill metadata preamble
    add_field_to_metadata(1) #fwu metadata version=1
    add_field_to_metadata(0) #active_index=0
    add_field_to_metadata(0) #previous_active_index=0

    for img_type_uuid, location_uuid, img_uuids in image_data:
        # Fill metadata image entry
        add_uuid_to_metadata(img_type_uuid) # img_type_uuid
        add_uuid_to_metadata(location_uuid) # location_uuid

        for img_uuid in img_uuids:
            # Fill metadata bank image info
            add_uuid_to_metadata(img_uuid) # image unique bank_uuid
            add_field_to_metadata(1)       # accepted=1
            add_field_to_metadata(0)       # reserved (MBZ)

     # Prepend CRC32
    with open(metadata_file, 'rb+') as fp:
        content = fp.read()
        crc = zlib.crc32(content)
        fp.seek(0)
        fp.write(crc.to_bytes(4, byteorder='little') + content)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument('--metadata_file', required=True,
                        help='Output binary file to store the metadata')
    parser.add_argument('--image_data', required=True,
                         help='image data in a format <img_type_uuid, \
                               location_uuid, <img_id1, img_id2, ...>')

    args = parser.parse_args()

    # evaluated the string containing the python literals
    image_data = ast.literal_eval(args.image_data)
    if not isinstance(image_data, list):
            raise argparse.ArgumentError("Invalid input format. \
                                          Please provide a valid list.")

    gen_fwu_metadata(args.metadata_file, image_data)
