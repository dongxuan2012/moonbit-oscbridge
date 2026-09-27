///|
fn fixture_cfg() -> String {
  ", , 1999\n" +
  "2, 1A, 1D\n" +
  "1, I-A, A, , A, 2, 1, 0, -100, 100, 10, 1, S\n" +
  "1, Breaker, A, , 0\n" +
  "50\n" +
  "1\n" +
  "1000, 3\n" +
  "01/01/0001, 01:01:01.000000\n" +
  "01/01/0001, 01:01:01.000000\n" +
  "ASCII\n" +
  "1"
}

///|
test "external application parses window, exports IPC, and reads it back" {
  let recording = @comtrade.parse(
    fixture_cfg(),
    "1,0,3,0\n2,1000,4,1\n3,2000,5,0",
  )
  let bytes = @adapter.write_window(recording, 0.001, 0.003, 2)
  let decoded = @arrow.read_file(bytes)
  assert_eq(decoded.batches.length(), 1)
  let batch = decoded.batches[0]
  assert_eq(batch.num_rows, 2)
  assert_eq(decoded.schema.fields.length(), 6)
  assert_true(batch.columns[0] is @arrow.Int32s([Some(2), Some(3)]))
  assert_true(batch.columns[1] is @arrow.Int64s([Some(1000L), Some(2000L)]))
  assert_true(batch.columns[2] is @arrow.Float64s([Some(0.001), Some(0.002)]))
  assert_true(batch.columns[3] is @arrow.Float64s([Some(4.0), Some(5.0)]))
  assert_true(batch.columns[4] is @arrow.Float64s([Some(9.0), Some(11.0)]))
  assert_true(batch.columns[5] is @arrow.Booleans([Some(true), Some(false)]))
  assert_eq(decoded.schema.metadata[0].value, Some("COMTRADE-1999 ASCII single-rate"))
  assert_eq(decoded.schema.metadata[7].value, Some("2"))
  assert_eq(decoded.schema.fields[1].metadata[0].value, Some("raw_tick"))
  assert_eq(decoded.schema.fields[1].metadata[2].value, Some("DAT tick"))
  assert_eq(decoded.schema.fields[4].metadata[7].value, Some("10"))
  assert_eq(decoded.schema.fields[4].metadata[8].value, Some("1"))
  assert_eq(decoded.schema.fields[4].metadata[9].value, Some("S"))
  assert_eq(decoded.schema.fields[4].metadata[10].value, Some("scaled"))
  assert_eq(decoded.schema.fields[4].metadata[11].value, Some("A"))
  assert_eq(
    decoded.schema.fields[4].metadata[12].value,
    Some("CFG a*raw+b on the P/S-declared side; unit is the CFG engineering unit; no side conversion"),
  )
}


