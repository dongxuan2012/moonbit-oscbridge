#!/usr/bin/env python3
"""Independent COMTRADE CSV/comtrade + PyArrow verification for the fixed sample."""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.metadata
import json
import math
from pathlib import Path

import pyarrow as pa
import pyarrow.ipc as ipc
from comtrade import Comtrade


EXPECTED_CFG_SHA256 = "656bc0a07bb4c422bd4bd3e14fd607dfd668fe8d0362c28c4c95e73096f36de2"
EXPECTED_DAT_SHA256 = "e968ea9567684117d189e74dec622bf417ead6f2611105a82a6f6c5029185253"
EXPECTED_ARCHIVE_SHA256 = "33a9fae8e21446b40a3099e6ffa733b679af4f3df4d4ce90aa4b06aeddf45ff8"
EXPECTED_ROWS = 10400
EXPECTED_ANALOG = 12
EXPECTED_STATUS = 13
ABS_TOL = 2e-12


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def approx(actual: float, expected: float, what: str) -> None:
    require(
        math.isclose(actual, expected, rel_tol=2e-12, abs_tol=ABS_TOL),
        f"{what}: actual={actual!r}, expected={expected!r}",
    )


def numeric_meta(meta: dict[str, str], key: str, expected: str, what: str) -> None:
    actual = float(meta[key])
    expected_value = float(expected)
    require(math.isfinite(actual), f"{what}: metadata is not finite")
    approx(actual, expected_value, what)


def decode_metadata(metadata: dict[bytes, bytes] | None) -> dict[str, str]:
    if not metadata:
        return {}
    return {key.decode("utf-8"): value.decode("utf-8") for key, value in metadata.items()}


def read_arrow(path: Path) -> pa.Table:
    require(path.is_file(), f"missing Arrow IPC file: {path}")
    with pa.memory_map(str(path), "r") as source:
        return ipc.open_file(source).read_all()


def column_values(table: pa.Table, name: str) -> list:
    require(name in table.column_names, f"missing IPC field {name!r}")
    column = table[name].combine_chunks()
    require(column.null_count == 0, f"unexpected null in {name}")
    return column.to_pylist()


def field_meta(table: pa.Table, name: str) -> dict[str, str]:
    idx = table.schema.get_field_index(name)
    require(idx >= 0, f"missing schema field {name!r}")
    return decode_metadata(table.schema.field(idx).metadata)


def require_any_key(meta: dict[str, str], candidates: tuple[str, ...], label: str) -> str:
    for key in candidates:
        if key in meta:
            return meta[key]
    raise AssertionError(f"missing {label} field metadata; present={sorted(meta)}")


def verify_field_layout(table: pa.Table, rec: Comtrade,
                        cfg_rows: list[list[str]], cfg_lines: list[str]) -> None:
    names = ["sample_number", "raw_ticks", "relative_seconds"]
    for i in range(rec.analog_count):
        names.extend((f"analog_{i + 1:03}_raw", f"analog_{i + 1:03}_scaled"))
    names.extend(f"status_{i + 1:03}" for i in range(rec.status_count))
    require(table.column_names == names, f"unexpected field layout: {table.column_names!r}")

    expected_types = [pa.int32(), pa.int64(), pa.float64()]
    expected_types.extend(t for _ in range(rec.analog_count) for t in (pa.float64(), pa.float64()))
    expected_types.extend(pa.bool_() for _ in range(rec.status_count))
    actual_types = [field.type for field in table.schema]
    require(actual_types == expected_types, f"unexpected Arrow types: {actual_types!r}")

    for i, channel in enumerate(rec.cfg.analog_channels):
        row = cfg_rows[2 + i]
        raw_cfg_line = cfg_lines[2 + i]
        for suffix, expected_kind, expected_unit in (
            ("raw", "raw", "raw-count"),
            ("scaled", "scaled", row[4].strip()),
        ):
            name = f"analog_{i + 1:03}_{suffix}"
            meta = field_meta(table, name)
            require(meta.get("channel_id") == row[0].strip(), f"analog {i + 1} channel id mismatch")
            require(meta.get("channel_name") == row[1].strip(), f"analog {i + 1} name mismatch")
            require(meta.get("phase") == row[2].strip(), f"analog {i + 1} phase mismatch")
            require(meta.get("circuit") == row[3].strip(), f"analog {i + 1} circuit mismatch")
            require(meta.get("cfg_unit") == row[4].strip(), f"analog {i + 1} CFG unit mismatch")
            require(meta.get("unit") == expected_unit, f"analog {i + 1} value unit mismatch")
            require(meta.get("value_kind") == expected_kind, f"analog {i + 1} value kind mismatch")
            require(meta.get("cfg_line_raw") == raw_cfg_line, f"analog {i + 1} raw CFG line was not preserved")
            numeric_meta(meta, "a", row[5], f"analog {i + 1} a")
            numeric_meta(meta, "b", row[6], f"analog {i + 1} b")
            numeric_meta(meta, "primary", row[10], f"analog {i + 1} primary")
            numeric_meta(meta, "secondary", row[11], f"analog {i + 1} secondary")
            require(meta.get("pors") == row[12].strip().upper(), f"analog {i + 1} P/S side mismatch")
            semantics = meta.get("value_semantics", "").lower()
            if expected_kind == "raw":
                require("raw" in semantics and "before" in semantics and "not a physical" in semantics,
                        f"analog {i + 1} raw semantics unclear")
            else:
                require("a*raw+b" in semantics and "declared side" in semantics and channel.pors.lower() in semantics,
                        f"analog {i + 1} scaled side/unit semantics unclear")

    status_start = 2 + rec.analog_count
    for i, channel in enumerate(rec.cfg.status_channels):
        row = cfg_rows[status_start + i]
        raw_cfg_line = cfg_lines[status_start + i]
        name = f"status_{i + 1:03}"
        meta = field_meta(table, name)
        require(meta.get("channel_id") == row[0].strip(), f"status {i + 1} id mismatch")
        require(meta.get("channel_name") == row[1].strip(), f"status {i + 1} name mismatch")
        require(meta.get("phase") == row[2].strip(), f"status {i + 1} phase mismatch")
        require(meta.get("circuit") == row[3].strip(), f"status {i + 1} circuit mismatch")
        require(meta.get("normal_state") == row[4].strip(), f"status {i + 1} normal state mismatch")
        require(meta.get("cfg_line_raw") == raw_cfg_line, f"status {i + 1} raw CFG line was not preserved")
        require(meta.get("value_kind") == "status", f"status {i + 1} kind mismatch")
        require("0/1" in meta.get("value_semantics", ""), f"status {i + 1} boolean mapping undocumented")
        require(int(row[4]) == channel.y, f"status {i + 1} Python reader normal state mismatch")


def verify_schema_metadata(table: pa.Table, expected_start: float, expected_end: float,
                           cfg_lines: list[str]) -> None:
    meta = decode_metadata(table.schema.metadata)
    require(meta, "missing Arrow schema metadata")

    profile = meta.get("comtrade.profile", "").lower()
    require("1999" in profile and "ascii" in profile, f"schema profile not preserved: {profile!r}")
    boundary = meta.get("comtrade.window_semantics", "").replace(" ", "")
    require(boundary == "[start,end)", f"window must declare [start,end): {boundary!r}")
    time_basis = meta.get("comtrade.time_coordinate", "").lower()
    require("relative" in time_basis and "dat" in time_basis, f"time basis must be relative DAT time: {time_basis!r}")
    require("timezone absent" in time_basis and "no utc claim" in time_basis,
            f"source has no absolute UTC basis: {time_basis!r}")
    require(meta.get("comtrade.start_datetime_raw") == cfg_lines[30], "raw CFG start date/time mismatch")
    require(meta.get("comtrade.trigger_datetime_raw") == cfg_lines[31], "raw CFG trigger date/time mismatch")
    require(math.isclose(float(meta["comtrade.window_start_seconds"]), expected_start, abs_tol=1e-12),
            "window start metadata mismatch")
    require(math.isclose(float(meta["comtrade.window_end_seconds"]), expected_end, abs_tol=1e-12),
            "window end metadata mismatch")


def verify_rows(table: pa.Table, sample_rows: list[list[str]], rec: Comtrade,
                time_multiplier: float,
                selected: list[int], label: str) -> None:
    require(table.num_rows == len(selected), f"{label}: row count {table.num_rows}, expected {len(selected)}")
    actual_samples = column_values(table, "sample_number")
    actual_ticks = column_values(table, "raw_ticks")
    actual_times = column_values(table, "relative_seconds")
    require(actual_samples == [int(sample_rows[i][0]) for i in selected], f"{label}: sample numbers differ from DAT")
    require(actual_ticks == [int(sample_rows[i][1]) for i in selected], f"{label}: raw DAT ticks differ")
    for out_index, source_index in enumerate(selected):
        approx(actual_times[out_index], rec.time[source_index], f"{label}: time row {source_index}")
        raw_tick_seconds = int(sample_rows[source_index][1]) * time_multiplier / 1000000.0
        approx(actual_times[out_index], raw_tick_seconds, f"{label}: DAT tick formula row {source_index}")

    analog_offset = 2
    for channel_index, channel in enumerate(rec.cfg.analog_channels):
        raw_values = column_values(table, f"analog_{channel_index + 1:03}_raw")
        scaled_values = column_values(table, f"analog_{channel_index + 1:03}_scaled")
        for out_index, source_index in enumerate(selected):
            raw = float(sample_rows[source_index][analog_offset + channel_index])
            approx(raw_values[out_index], raw, f"{label}: analog {channel_index + 1} raw row {source_index}")
            expected_scaled = channel.a * raw + channel.b
            approx(scaled_values[out_index], expected_scaled,
                   f"{label}: analog {channel_index + 1} formula row {source_index}")
            approx(scaled_values[out_index], rec.analog[channel_index][source_index],
                   f"{label}: analog {channel_index + 1} comtrade row {source_index}")

    status_offset = 2 + rec.analog_count
    for channel_index in range(rec.status_count):
        values = column_values(table, f"status_{channel_index + 1:03}")
        expected = [bool(int(sample_rows[i][status_offset + channel_index])) for i in selected]
        require(values == expected, f"{label}: status {channel_index + 1} differs from DAT")
        require(values == [bool(rec.status[channel_index][i]) for i in selected],
                f"{label}: status {channel_index + 1} differs from comtrade reader")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cfg", type=Path, required=True)
    parser.add_argument("--dat", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True,
                        help="full fixed-hash archive used to source the CFG/DAT pair")
    parser.add_argument("--full", type=Path, required=True)
    parser.add_argument("--window", type=Path, required=True,
                        help="Arrow IPC for [1.0, 1.1) seconds")
    parser.add_argument("--empty", type=Path, required=True,
                        help="Arrow IPC for the empty [1.0, 1.0) window")
    args = parser.parse_args()

    cfg_hash, dat_hash = sha256(args.cfg), sha256(args.dat)
    require(cfg_hash == EXPECTED_CFG_SHA256, f"unexpected CFG SHA-256: {cfg_hash}")
    require(dat_hash == EXPECTED_DAT_SHA256, f"unexpected DAT SHA-256: {dat_hash}")
    archive_hash = sha256(args.archive)
    require(archive_hash == EXPECTED_ARCHIVE_SHA256, f"unexpected archive SHA-256: {archive_hash}")

    with args.dat.open("r", encoding="ascii", newline="") as stream:
        sample_rows = list(csv.reader(stream))
    cfg_lines = args.cfg.read_text(encoding="ascii").splitlines()
    with args.cfg.open("r", encoding="ascii", newline="") as stream:
        cfg_rows = list(csv.reader(stream))
    reader = Comtrade(use_double_precision=True)
    reader.load(str(args.cfg), str(args.dat))
    require(reader.rev_year == "1999" and reader.ft.upper() == "ASCII", "expected COMTRADE-1999 ASCII")
    require(reader.total_samples == EXPECTED_ROWS and len(sample_rows) == EXPECTED_ROWS, "expected all 10,400 source rows")
    require(reader.analog_count == EXPECTED_ANALOG and reader.status_count == EXPECTED_STATUS,
            "expected the fixed 12A/13D OscGrid record")
    require(reader.cfg.sample_rates == [[1600.0, EXPECTED_ROWS]], "unexpected sample-rate declaration")
    time_multiplier = float(cfg_rows[33][0])
    require(math.isclose(time_multiplier, reader.cfg.timemult, rel_tol=0, abs_tol=0),
            "CFG multiplier differs from comtrade parser")
    require(all(len(row) == 2 + EXPECTED_ANALOG + EXPECTED_STATUS for row in sample_rows),
            "unexpected DAT row width")
    require(not any(field.strip() == "99999" for row in sample_rows for field in row[2:2 + EXPECTED_ANALOG]),
            "fixed record unexpectedly contains the unsupported ASCII missing-value marker")

    full = read_arrow(args.full)
    window = read_arrow(args.window)
    empty = read_arrow(args.empty)
    for table in (full, window, empty):
        verify_field_layout(table, reader, cfg_rows, cfg_lines)
    full_fields = [(f.name, f.type, f.metadata) for f in full.schema]
    require([(f.name, f.type, f.metadata) for f in window.schema] == full_fields,
            "window IPC field schema/metadata differs from full IPC")
    require([(f.name, f.type, f.metadata) for f in empty.schema] == full_fields,
            "empty IPC field schema/metadata differs from full IPC")

    verify_schema_metadata(full, 0.0, 7.0, cfg_lines)
    verify_schema_metadata(window, 1.0, 1.1, cfg_lines)
    verify_schema_metadata(empty, 1.0, 1.0, cfg_lines)

    full_indices = list(range(EXPECTED_ROWS))
    dat_times = [int(row[1]) * time_multiplier / 1000000.0 for row in sample_rows]
    window_indices = [i for i, t in enumerate(dat_times) if 1.0 <= t < 1.1]
    require(len(window_indices) == 160, f"expected 160 samples in [1,1.1), got {len(window_indices)}")
    require(dat_times[window_indices[0]] == 1.0, "left-boundary sample at 1.0 must exist")
    require(dat_times[window_indices[-1]] < 1.1, "right-boundary sample at 1.1 must be excluded")
    require(any(t == 1.1 for t in dat_times), "fixed input must contain a sample exactly at 1.1")
    verify_rows(full, sample_rows, reader, time_multiplier, full_indices, "full")
    verify_rows(window, sample_rows, reader, time_multiplier, window_indices, "[1,1.1)")
    verify_rows(empty, sample_rows, reader, time_multiplier, [], "empty")

    receipt = {
        "result": "PASS",
        "source": {
            "dataset": "OscGrid Labeled_raw_v1.1, fixed COMTRADE pair",
            "upstream": {
                "repository": "https://github.com/AIRI-Institute/oscgrid/tree/4cbdf81f9a05f646b5e4ee508e273a7b8e92b056",
                "archive": "https://doi.org/10.6084/m9.figshare.28465427.v6",
                "archiveSha256": archive_hash,
                "license": "CC BY 4.0",
            },
            "recordRelativePath": "Labeled_raw_v1.1/4bbe281f8abafac243fafb0a0c2f047c",
            "cfg": {"sha256": cfg_hash, "bytes": args.cfg.stat().st_size},
            "dat": {"sha256": dat_hash, "bytes": args.dat.stat().st_size},
            "rows": len(sample_rows),
            "analogChannels": reader.analog_count,
            "statusChannels": reader.status_count,
            "timeRangeSeconds": [reader.time[0], reader.time[-1]],
            "datTickTimeRangeSeconds": [dat_times[0], dat_times[-1]],
            "maxAbsDifferenceReaderSampleRateVsDatTickTime": max(
                abs(reader.time[i] - dat_times[i]) for i in range(EXPECTED_ROWS)
            ),
            "missingAnalogMarkerObserved": False,
            "sourceStartDateRaw": cfg_lines[30],
            "sourceTriggerDateRaw": cfg_lines[31],
            "timeMultiplier": time_multiplier,
        },
        "reference": {
            "comtrade": importlib.metadata.version("comtrade"),
            "pyarrow": pa.__version__,
            "python": __import__("sys").version.split()[0],
        },
        "ipc": {
            "full": {"path": str(args.full), "sha256": sha256(args.full), "bytes": args.full.stat().st_size,
                     "rows": full.num_rows, "columns": full.num_columns},
            "window_1_1_1": {"path": str(args.window), "sha256": sha256(args.window),
                             "bytes": args.window.stat().st_size, "rows": window.num_rows},
            "empty_1_1": {"path": str(args.empty), "sha256": sha256(args.empty),
                          "bytes": args.empty.stat().st_size, "rows": empty.num_rows},
        },
        "comparisons": {
            "sample_numbers": EXPECTED_ROWS,
            "raw_dat_ticks": EXPECTED_ROWS,
            "relative_times": EXPECTED_ROWS,
            "relative_time_checked_against_raw_DAT_ticks": EXPECTED_ROWS,
            "analog_raw_values": EXPECTED_ROWS * EXPECTED_ANALOG,
            "analog_scaled_against_formula_and_comtrade": EXPECTED_ROWS * EXPECTED_ANALOG,
            "status_values_against_dat_and_comtrade": EXPECTED_ROWS * EXPECTED_STATUS,
            "window_rows": len(window_indices),
            "left_boundary_1_0_included": True,
            "right_boundary_1_1_excluded": True,
            "empty_window_has_same_fields_and_metadata": empty.num_rows == 0,
            "reader_time_basis_note": "comtrade 0.1.2 reconstructs this single-rate time axis from sample index/rate; DAT-tick formula was independently checked as well",
        },
        "scopeLimits": [
            "This one anonymized public record does not validate all COMTRADE revisions or DAT encodings.",
            "The record's start timestamp is year 0001; no absolute UTC or real event-time claim is made.",
            "The record-specific class label was not cross-checked against a fault diagnosis.",
            "Missing sample timestamps and malformed/dynamic inputs are outside this independent data comparison.",
            "The fixed source has no 99999 analog missing marker; marker/null behavior is not validated here.",
            "PyArrow and Python comtrade are verification tools only, not the MoonBit runtime core.",
        ],
    }
    print(json.dumps(receipt, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
