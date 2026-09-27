///|
fn fixture_cfg(
  rate : String,
  row_count : Int,
  minimum : String,
  maximum : String,
  skew : String,
  time_multiplier : String,
) -> String {
  ", , 1999\n" +
  "2, 1A, 1D\n" +
  "1, I-A, A, , A, 2, 1, " +
  skew +
  ", " +
  minimum +
  ", " +
  maximum +
  ", 10, 1, S\n" +
  "1, Breaker, A, , 0\n" +
  "50\n" +
  "1\n" +
  rate +
  ", " +
  row_count.to_string() +
  "\n" +
  "01/01/0001, 01:01:01.000000\n" +
  "01/01/0001, 01:01:01.000000\n" +
  "ASCII\n" +
  time_multiplier
}

///|
fn parse_rejected(
  cfg : String,
  dat : String,
  expected_section : String,
) -> Bool {
  try {
    ignore(parse(cfg, dat))
    false
  } catch {
    Rejected(section, _, _) => section == expected_section
  }
}

///|
test "single-rate record preserves source metadata and window identity" {
  let recording = parse(
    fixture_cfg("1000", 2, "-100", "100", "0", "1"),
    "1,0,3,0\n2,1000,4,1",
  )
  assert_eq(recording.revision(), 1999)
  assert_eq(recording.start_datetime_raw(), "01/01/0001, 01:01:01.000000")
  assert_eq(recording.sampling_rate_hz(), 1000.0)
  assert_eq(recording.sample_count(), 2)
  let window = recording.window(0.001, 0.002)
  assert_eq(window.samples.length(), 1)
  assert_eq(window.samples[0].sample_number, 2)
  assert_eq(window.samples[0].raw_ticks, 1000L)
  assert_eq(window.samples[0].time_seconds, 0.001)
  assert_eq(window.samples[0].analog_raw[0], 4.0)
  assert_true(window.samples[0].status[0])
  let analog = window.analog_channels[0]
  assert_eq(analog.number_raw, "1")
  assert_eq(analog.scale_a_raw, "2")
  assert_eq(analog.offset_b_raw, "1")
  assert_eq(analog.pors, "S")
  // P/S is metadata; the declared-side equation is 2*4+1, not ratio-scaled.
  assert_eq(analog.scaled(window.samples[0].analog_raw[0]), 9.0)
}

///|
test "window uses half-open bounds and caller-owned sample arrays" {
  let recording = parse(
    fixture_cfg("1000", 2, "-100", "100", "0", "1"),
    "1,0,3,0\n2,1000,4,1",
  )
  assert_eq(recording.window(0.0, 0.001).samples.length(), 1)
  assert_eq(recording.window(0.001, 0.001).samples.length(), 0)
  assert_true(
    try {
      ignore(recording.window(1.0, 0.0))
      false
    } catch {
      Rejected(section, _, _) => section == "window"
    },
  )
  let snapshot = recording.window(0.001, 0.002)
  snapshot.samples[0].analog_raw[0] = 88.0
  assert_eq(recording.window(0.001, 0.002).samples[0].analog_raw[0], 4.0)
  assert_true(
    try {
      ignore(recording.window(0.0, 0.002, max_rows=1))
      false
    } catch {
      Rejected(section, _, _) => section == "window"
    },
  )
}

///|
test "one raw tick cadence tolerance is accepted and larger mismatch rejected" {
  let within = parse(
    fixture_cfg("1000", 2, "-100", "100", "0", "1"),
    "1,0,3,0\n2,1001,4,1",
  )
  assert_eq(within.sample_count(), 2)
  assert_true(
    parse_rejected(
      fixture_cfg("1000", 2, "-100", "100", "0", "1"),
      "1,0,3,0\n2,1002,4,1",
      "dat",
    ),
  )
}

///|
test "unrepresentable distinct ticks do not collapse into equal window time" {
  let cfg = fixture_cfg("1e106", 2, "-100", "100", "0", "1e-100")
  assert_true(
    parse_rejected(
      cfg, "1,9000000000000000000,3,0\n2,9000000000000000001,4,1", "dat",
    ),
  )
}

///|
test "malformed declarations, skew, range, missing marker, and status fail closed" {
  assert_true(
    parse_rejected(
      fixture_cfg("1000", 2, "-100", "100", "0.5", "1"),
      "1,0,3,0\n2,1000,4,1",
      "cfg",
    ),
  )
  assert_true(
    parse_rejected(
      fixture_cfg("1000", 2, "-100", "100", "0", "1"),
      "1,0,3,0\n2,1000,101,1",
      "dat",
    ),
  )
  assert_true(
    parse_rejected(
      fixture_cfg("1000", 2, "-100000", "100000", "0", "1"),
      "1,0,3,0\n2,1000,99999,1",
      "dat",
    ),
  )
  assert_true(
    parse_rejected(
      fixture_cfg("1000", 2, "-100", "100", "0", "1"),
      "1,0,3,0\n2,1000,4,2",
      "dat",
    ),
  )
  assert_true(
    parse_rejected(
      fixture_cfg("1000", 2, "-100", "100", "0", "1"),
      "1,0,3,0\n2,1000,NaN,1",
      "dat",
    ),
  )
}

///|
test "decoded cell budget rejects before attempting DAT allocation" {
  let cfg = StringBuilder()
  cfg.write_string(", , 1999\n11, 10A, 1D\n")
  for i in 1..<11 {
    cfg.write_string(
      i.to_string() +
      ", A" +
      i.to_string() +
      ", A, , V, 1, 0, 0, -100, 100, 10, 1, S\n",
    )
  }
  cfg.write_string("1, Status, A, , 0\n50\n1\n1000, 200000\n")
  cfg.write_string(
    "01/01/0001, 01:01:01.000000\n01/01/0001, 01:01:01.000000\nASCII\n1",
  )
  assert_true(parse_rejected(cfg.to_string(), "", "capacity"))
}
