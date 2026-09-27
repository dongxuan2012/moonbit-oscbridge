# COMTRADE to MoonArrow prototype result

**Local prototype only.** The trial is a reusable engineering task, not evidence of adoption, an award, or official approval. The public API is `localreview/oscbridge/arrow.write_window(recording, start_seconds, end_seconds, max_rows)`, implemented in [window_to_ipc.mbt](../../arrow/window_to_ipc.mbt). The [JS bridge](../../cmd/arrow/arrow_bridge.mbt) exposes the byte result; bounded input reads and exclusive file publication stay in the Node host. IPC is written by the published `shunge/arrow@0.1.0` `write_file` API.

The fixed OscGrid `Labeled_raw_v1.1` pair is CC BY 4.0. Its archive, CFG, and DAT SHA-256 fingerprints and attribution URLs are in [RUN-RECEIPT.json](RUN-RECEIPT.json); the source archive is not included here. This pair declares COMTRADE-1999 ASCII, 10,400 rows, 12 analog channels, and 13 status channels. No absolute-time claim is made: both CFG timestamps say `01/01/0001, 01:01:01.000000`.

PyArrow 25.0.1 independently read the Arrow IPC files. Python `comtrade==0.1.2` and a separate CSV read supplied reference values. Across all 10,400 rows, verification matched sample number, original DAT tick, relative seconds, 124,800 raw analog values, 124,800 `a*raw+b` values against both the formula and Python reader, and 135,200 status values. The tick formula was independently evaluated from DAT ticks and CFG multiplier; the Python reader's time is reconstructed from the declared single rate, and both agreed for this sample. The `[1.0,1.1)` window contains the sample at `1.0` and excludes the sample at `1.1`. A zero-width `[1.0,1.0)` file has zero rows and the same column schema and field metadata.

| IPC file | Rows | Columns | Bytes | SHA-256 |
| --- | ---: | ---: | ---: | --- |
| `full.arrow` | 10,400 | 40 | 2,307,450 | `64331726deea9fc43411bad998e0d6de097ce879cb4e9841b029a9f14c1fa6fb` |
| `window-1-1-1.arrow` | 160 | 40 | 119,930 | `6caef4c354ab2baeb115cbef6e9d2399a457042dffb3a48654fa1c124202497d` |
| `empty-1-1.arrow` | 0 | 40 | 85,698 | `657f2a2b3a6d118eb367560eb3f2fbe6c11178d7910434535dc16107d74bfcae` |

The schema contains original sample identity and ticks, relative seconds, raw and scaled Float64 columns for each analog channel, and Boolean columns for status channels. Field metadata records channel identity and CFG definitions. Raw columns are explicitly marked `raw-count` and “not a physical engineering value”; scaled columns are marked with the CFG unit and P/S-declared side, with no extra ratio conversion. Schema metadata retains raw start/trigger strings, profile, window bounds, and the relative-DAT/no-UTC convention.

The bounded scope remains one anonymized single-rate ASCII record, not all COMTRADE revisions or encodings. Its record-specific class label was not checked against a diagnosis. The source contains no analog `99999` missing marker, so missing-value/null behavior is unverified. No event interpretation, fault diagnosis, or field adoption is claimed. The exact value counts and executable comparison are in [PYARROW-CROSSCHECK.json](PYARROW-CROSSCHECK.json); parent-run host failure checks are recorded separately in the path named in [RUN-RECEIPT.json](RUN-RECEIPT.json).
