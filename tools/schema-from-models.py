#!/usr/bin/env python3
# Prints the CloudKit record types for the synced SwiftData models in Shared/Models.swift.
# usage: tools/schema-from-models.py Shared/Models.swift HealthValue   (device-only models to skip)
# Paste the output between DEFINE SCHEMA and the Users record in cloudkit/schema.ckdb.
import re, sys
src = open(sys.argv[1]).read()
types = {"String": "STRING", "Int": "INT64", "Double": "DOUBLE", "Bool": "INT64", "Date": "TIMESTAMP", "UUID": "STRING"}
models = re.findall(r'@Model\s+final class (\w+)\s*\{(.*?)\n\}', src, re.S)
skip = set(sys.argv[2:])
out = []
for name, body in models:
    if name in skip: continue
    fields = {"CD_entityName": "STRING"}
    for m in re.finditer(r'^\s{4}var (\w+): (\w+)\??(?: =|$)', body, re.M):
        attr, typ = m.group(1), m.group(2)
        if typ not in types: raise SystemExit(f"unknown type {typ} in {name}.{attr}")
        fields["CD_" + attr] = types[typ]
    lines = ['        "___createTime" TIMESTAMP,', '        "___createdBy"  REFERENCE,', '        "___etag"       STRING,',
             '        "___modTime"    TIMESTAMP,', '        "___modifiedBy" REFERENCE,', '        "___recordID"   REFERENCE QUERYABLE,']
    width = max(len(k) for k in fields)
    for k in sorted(fields):
        lines.append(f"        {k.ljust(width)} {fields[k]},")
    lines += ['        GRANT WRITE TO "_creator",', '        GRANT CREATE TO "_icloud",', '        GRANT READ TO "_world"']
    out.append(f"    RECORD TYPE CD_{name} (\n" + "\n".join(lines) + "\n    );")
print("\n\n".join(out))
