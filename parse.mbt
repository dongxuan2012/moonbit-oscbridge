///|
/// The trial profile is intentionally narrower than IEEE C37.111: revision
/// 1999 declaration, ASCII DAT, one positive sampling-rate segment, zero
/// analog skew, finite bounded values, and binary status values only.
pub fn parse(cfg : String, dat : String) -> Recording raise ComtradeError {
  if cfg.length() > 33554432 ||
    dat.length() > 33554432 ||
    cfg.length() > 33554432 - dat.length() {
    raise Rejected("capacity", 0, "CFG+DAT exceeds 32 MiB text budget")
  }
  let cfg_lines = normalized_lines(cfg, "cfg", 300)
  if cfg_lines.length() < 8 {
    raise Rejected("cfg", 0, "truncated configuration")
  }
  let mut pos = 0
  let header_line = cfg_lines[pos]
  pos += 1
  let header = csv_fields(header_line, "cfg", pos)
  expect_fields(header, 3, "cfg", pos)
  let station_name = header[0]
  let device_id = header[1]
  if parse_int_field(header[2], "cfg", pos) != 1999 {
    raise Rejected("cfg", pos, "only revision 1999 is supported")
  }
  let count_line = cfg_lines[pos]
  pos += 1
  let counts = csv_fields(count_line, "cfg", pos)
  expect_fields(counts, 3, "cfg", pos)
  let total_channels = parse_int_field(counts[0], "cfg", pos)
  let analog_count = channel_count(counts[1], "A", pos)
  let status_count = channel_count(counts[2], "D", pos)
  if analog_count > 256 || status_count > 256 {
    raise Rejected("cfg", pos, "analog/status channel count exceeds 256")
  }
  if total_channels <= 0 || total_channels > 256 {
    raise Rejected("cfg", pos, "channel total must be in 1..256")
  }
  if analog_count + status_count != total_channels {
    raise Rejected("cfg", pos, "channel totals are inconsistent")
  }
  let analog : Array[AnalogChannel] = []
  let analog_seen : Map[Int, Bool] = Map([])
  for _ in 0..<analog_count {
    if pos >= cfg_lines.length() {
      raise Rejected("cfg", pos + 1, "truncated analog channel declarations")
    }
    let line = cfg_lines[pos]
    pos += 1
    let fields = csv_fields(line, "cfg", pos)
    expect_fields(fields, 13, "cfg", pos)
    let number = parse_int_field(fields[0], "cfg", pos)
    if number <= 0 || analog_seen.contains(number) {
      raise Rejected(
        "cfg", pos, "analog channel number must be positive and unique",
      )
    }
    analog_seen[number] = true
    let scale_a = parse_number(fields[5], "cfg", pos)
    let offset_b = parse_number(fields[6], "cfg", pos)
    let skew = parse_number(fields[7], "cfg", pos)
    let minimum = parse_number(fields[8], "cfg", pos)
    let maximum = parse_number(fields[9], "cfg", pos)
    let primary = parse_number(fields[10], "cfg", pos)
    let secondary = parse_number(fields[11], "cfg", pos)
    let pors = fields[12].to_upper()
    if skew != 0.0 {
      raise Rejected("cfg", pos, "nonzero analog skew is unsupported")
    }
    if minimum > maximum {
      raise Rejected("cfg", pos, "analog min exceeds max")
    }
    if primary <= 0.0 || secondary <= 0.0 {
      raise Rejected("cfg", pos, "primary/secondary ratios must be positive")
    }
    if pors != "P" && pors != "S" {
      raise Rejected("cfg", pos, "P/S side indicator must be P or S")
    }
    analog.push({
      number,
      number_raw: fields[0],
      name: fields[1],
      phase: fields[2],
      circuit: fields[3],
      unit: fields[4],
      scale_a,
      scale_a_raw: fields[5],
      offset_b,
      offset_b_raw: fields[6],
      minimum,
      minimum_raw: fields[8],
      maximum,
      maximum_raw: fields[9],
      primary,
      primary_raw: fields[10],
      secondary,
      secondary_raw: fields[11],
      pors,
      cfg_line_raw: line,
    })
  }
  let digital : Array[StatusChannel] = []
  let digital_seen : Map[Int, Bool] = Map([])
  for _ in 0..<status_count {
    if pos >= cfg_lines.length() {
      raise Rejected("cfg", pos + 1, "truncated status channel declarations")
    }
    let line = cfg_lines[pos]
    pos += 1
    let fields = csv_fields(line, "cfg", pos)
    expect_fields(fields, 5, "cfg", pos)
    let number = parse_int_field(fields[0], "cfg", pos)
    if number <= 0 || digital_seen.contains(number) {
      raise Rejected(
        "cfg", pos, "status channel number must be positive and unique",
      )
    }
    digital_seen[number] = true
    let initial = parse_int_field(fields[4], "cfg", pos)
    if initial != 0 && initial != 1 {
      raise Rejected("cfg", pos, "status normal state must be 0 or 1")
    }
    digital.push({
      number,
      number_raw: fields[0],
      name: fields[1],
      phase: fields[2],
      circuit: fields[3],
      initial_value: initial,
      normal_state_raw: fields[4],
      cfg_line_raw: line,
    })
  }
  if pos >= cfg_lines.length() {
    raise Rejected("cfg", pos + 1, "missing nominal frequency")
  }
  let frequency_line = cfg_lines[pos]
  pos += 1
  let frequency_fields = csv_fields(frequency_line, "cfg", pos)
  expect_fields(frequency_fields, 1, "cfg", pos)
  let nominal_frequency_hz = parse_number(frequency_fields[0], "cfg", pos)
  if nominal_frequency_hz <= 0.0 {
    raise Rejected("cfg", pos, "nominal frequency must be positive")
  }
  if pos >= cfg_lines.length() {
    raise Rejected("cfg", pos + 1, "missing sampling-rate segment count")
  }
  let segments_line = cfg_lines[pos]
  pos += 1
  let segments_fields = csv_fields(segments_line, "cfg", pos)
  expect_fields(segments_fields, 1, "cfg", pos)
  if parse_int_field(segments_fields[0], "cfg", pos) != 1 {
    raise Rejected("cfg", pos, "exactly one sampling-rate segment is supported")
  }
  if pos >= cfg_lines.length() {
    raise Rejected("cfg", pos + 1, "missing sampling-rate segment")
  }
  let rate_line = cfg_lines[pos]
  pos += 1
  let rate_fields = csv_fields(rate_line, "cfg", pos)
  expect_fields(rate_fields, 2, "cfg", pos)
  let sampling_rate_hz = parse_number(rate_fields[0], "cfg", pos)
  let row_count = parse_int_field(rate_fields[1], "cfg", pos)
  if sampling_rate_hz <= 0.0 {
    raise Rejected("cfg", pos, "sampling rate must be positive")
  }
  if row_count <= 0 || row_count > 200000 {
    raise Rejected("cfg", pos, "declared row count must be in 1..200000")
  }
  // Reject decoded-value expansion before creating row/channel arrays.
  if row_count * total_channels > 2000000 {
    raise Rejected(
      "capacity", pos, "record exceeds 2,000,000 channel-value budget",
    )
  }
  if pos + 4 > cfg_lines.length() {
    raise Rejected(
      "cfg",
      pos + 1,
      "truncated time, format, or multiplier declarations",
    )
  }
  let start_line = cfg_lines[pos]
  pos += 1
  let start_fields = csv_fields(start_line, "cfg", pos)
  expect_fields(start_fields, 2, "cfg", pos)
  if start_fields[0].is_empty() || start_fields[1].is_empty() {
    raise Rejected("cfg", pos, "start date/time fields cannot be empty")
  }
  let trigger_line = cfg_lines[pos]
  pos += 1
  let trigger_fields = csv_fields(trigger_line, "cfg", pos)
  expect_fields(trigger_fields, 2, "cfg", pos)
  if trigger_fields[0].is_empty() || trigger_fields[1].is_empty() {
    raise Rejected("cfg", pos, "trigger date/time fields cannot be empty")
  }
  let format_line = cfg_lines[pos]
  pos += 1
  let format_fields = csv_fields(format_line, "cfg", pos)
  expect_fields(format_fields, 1, "cfg", pos)
  if format_fields[0].to_upper() != "ASCII" {
    raise Rejected("cfg", pos, "only ASCII DAT is supported")
  }
  let multiplier_line = cfg_lines[pos]
  pos += 1
  let multiplier_fields = csv_fields(multiplier_line, "cfg", pos)
  expect_fields(multiplier_fields, 1, "cfg", pos)
  let time_multiplier = parse_number(multiplier_fields[0], "cfg", pos)
  if time_multiplier <= 0.0 {
    raise Rejected("cfg", pos, "time multiplier must be positive")
  }
  let tick_seconds = time_multiplier / 1000000.0
  let expected_interval = 1.0 / sampling_rate_hz
  if !finite(tick_seconds) ||
    tick_seconds <= 0.0 ||
    !finite(expected_interval) ||
    expected_interval <= 0.0 {
    raise Rejected(
      "cfg", pos, "time scale or sample interval is not representable",
    )
  }
  if pos != cfg_lines.length() {
    raise Rejected("cfg", pos + 1, "trailing CFG lines are unsupported")
  }
  let dat_lines = normalized_lines(dat, "dat", 200002)
  if dat_lines.length() != row_count {
    raise Rejected("dat", 0, "DAT row count does not match CFG final sample")
  }
  let rows : Array[Sample] = []
  let expected_fields = 2 + total_channels
  let mut previous_ticks : Int64? = None
  let mut previous_time : Double? = None
  for row_index in 0..<dat_lines.length() {
    let line = dat_lines[row_index]
    let line_no = row_index + 1
    let fields = csv_fields(line, "dat", line_no)
    expect_fields(fields, expected_fields, "dat", line_no)
    let sample_number = parse_int_field(fields[0], "dat", line_no)
    if sample_number != row_index + 1 {
      raise Rejected("dat", line_no, "sample numbers must be exactly 1..N")
    }
    let raw_ticks = parse_nonnegative_int64(fields[1], "dat", line_no)
    if previous_ticks is Some(previous) {
      let tick_delta = raw_ticks - previous
      if tick_delta <= 0L {
        raise Rejected("dat", line_no, "timestamps must be strictly increasing")
      }
      let actual_delta = tick_delta.to_double() * tick_seconds
      let round_tolerance = 1.7763568394002505e-15 *
        actual_delta.abs().max(expected_interval.abs())
      let tolerance = tick_seconds + round_tolerance
      if !finite(actual_delta) ||
        actual_delta <= 0.0 ||
        (actual_delta - expected_interval).abs() > tolerance {
        raise Rejected(
          "dat", line_no, "timestamp spacing disagrees with single-rate CFG by more than one tick",
        )
      }
    }
    previous_ticks = Some(raw_ticks)
    let time_seconds = raw_ticks.to_double() * time_multiplier / 1000000.0
    if !finite(time_seconds) {
      raise Rejected("dat", line_no, "DAT time is non-finite")
    }
    if previous_time is Some(previous) && time_seconds <= previous {
      raise Rejected(
        "dat", line_no, "DAT time is not strictly increasing as Double seconds",
      )
    }
    previous_time = Some(time_seconds)
    let analog_raw : Array[Double] = []
    for channel_index in 0..<analog_count {
      let raw = parse_number(fields[2 + channel_index], "dat", line_no)
      let channel = analog[channel_index]
      if raw == 99999.0 {
        raise Rejected(
          "dat", line_no, "ASCII analog 99999 reserved/missing value is unsupported",
        )
      }
      if raw < channel.minimum || raw > channel.maximum {
        raise Rejected("dat", line_no, "analog raw value outside CFG min/max")
      }
      let scaled = channel.scale_a * raw + channel.offset_b
      if !finite(scaled) {
        raise Rejected("dat", line_no, "scaled analog value is non-finite")
      }
      analog_raw.push(raw)
    }
    let status : Array[Bool] = []
    for channel_index in 0..<status_count {
      let raw = parse_int_field(
        fields[2 + analog_count + channel_index],
        "dat",
        line_no,
      )
      if raw != 0 && raw != 1 {
        raise Rejected("dat", line_no, "status values must be exactly 0 or 1")
      }
      status.push(raw == 1)
    }
    rows.push({ sample_number, raw_ticks, time_seconds, analog_raw, status, })
  }
  {
    station_name,
    device_id,
    revision: 1999,
    nominal_frequency_hz,
    sampling_rate_hz,
    time_multiplier,
    start_datetime_raw: start_line,
    trigger_datetime_raw: trigger_line,
    analog,
    digital,
    rows,
  }
}

///|
fn normalized_lines(
  text : String,
  section : String,
  max_lines : Int,
) -> Array[String] raise ComtradeError {
  let builder = StringBuilder()
  let mut physical_lines = 1
  let mut line_width = 0
  let mut previous_cr = false
  for c in text {
    if c == '\r' {
      physical_lines += 1
      if physical_lines > max_lines + 1 {
        raise Rejected(section, 0, "line count exceeds profile budget")
      }
      builder.write_char('\n')
      line_width = 0
      previous_cr = true
    } else if c == '\n' {
      if !previous_cr {
        physical_lines += 1
        if physical_lines > max_lines + 1 {
          raise Rejected(section, 0, "line count exceeds profile budget")
        }
        builder.write_char('\n')
        line_width = 0
      }
      previous_cr = false
    } else {
      previous_cr = false
      if c != '\t' && (c < ' ' || c > '~') {
        raise Rejected(
          section, 0, "only printable ASCII, tabs, and line endings are supported",
        )
      }
      line_width += 1
      if line_width > 65536 {
        raise Rejected(
          section, 0, "line exceeds 65,536-character profile budget",
        )
      }
      builder.write_char(c)
    }
  }
  let normalized = builder.to_string()
  let body = if normalized.length() > 0 &&
    normalized[normalized.length() - 1] == '\n' {
    normalized[:normalized.length() - 1].to_owned()
  } else {
    normalized
  }
  body.split("\n").map(line => line.to_owned()).to_array()
}

///|
fn csv_fields(
  line : String,
  section : String,
  line_no : Int,
) -> Array[String] raise ComtradeError {
  let chars = line.to_array()
  let fields : Array[String] = []
  let buffer = StringBuilder()
  let mut quoted = false
  let mut after_quote = false
  let mut index = 0
  while index < chars.length() {
    let c = chars[index]
    if quoted {
      if c == '"' {
        if index + 1 < chars.length() && chars[index + 1] == '"' {
          buffer.write_char('"')
          index += 2
        } else {
          quoted = false
          after_quote = true
          index += 1
        }
      } else {
        buffer.write_char(c)
        index += 1
      }
    } else if after_quote {
      if c == ',' {
        fields.push(buffer.to_string())
        buffer.reset()
        after_quote = false
        index += 1
      } else if c == ' ' || c == '\t' {
        index += 1
      } else {
        raise Rejected(
          section, line_no, "unexpected character after quoted CSV field",
        )
      }
    } else if c == ',' {
      fields.push(buffer.to_string().trim().to_owned())
      buffer.reset()
      index += 1
    } else if c == '"' {
      if !buffer.to_string().trim().is_empty() {
        raise Rejected(section, line_no, "quote inside unquoted CSV field")
      }
      buffer.reset()
      quoted = true
      index += 1
    } else {
      buffer.write_char(c)
      index += 1
    }
  }
  if quoted {
    raise Rejected(section, line_no, "unterminated quoted CSV field")
  }
  fields.push(
    if after_quote {
      buffer.to_string()
    } else {
      buffer.to_string().trim().to_owned()
    },
  )
  fields
}

///|
fn expect_fields(
  fields : Array[String],
  expected : Int,
  section : String,
  line_no : Int,
) -> Unit raise ComtradeError {
  if fields.length() != expected {
    raise Rejected(
      section,
      line_no,
      "expected " +
      expected.to_string() +
      " fields, found " +
      fields.length().to_string(),
    )
  }
}

///|
fn channel_count(
  text : String,
  suffix : String,
  line_no : Int,
) -> Int raise ComtradeError {
  let value = text.trim().to_owned().to_upper()
  if value.length() < 2 ||
    (suffix == "A" && value[value.length() - 1] != 'A') ||
    (suffix == "D" && value[value.length() - 1] != 'D') {
    raise Rejected("cfg", line_no, "channel count must end in " + suffix)
  }
  let count = parse_int_field(
    value[:value.length() - 1].to_owned(),
    "cfg",
    line_no,
  )
  if count < 0 {
    raise Rejected("cfg", line_no, "channel count cannot be negative")
  }
  count
}

///|
fn parse_int_field(
  text : String,
  section : String,
  line_no : Int,
) -> Int raise ComtradeError {
  let value = text.trim().to_owned()
  if value.is_empty() {
    raise Rejected(section, line_no, "empty integer field")
  }
  for c in value {
    if (c < '0' || c > '9') && c != '+' && c != '-' {
      raise Rejected(section, line_no, "invalid integer field")
    }
  }
  @string.parse_int(value, base=10) catch {
    _ =>
      raise Rejected(
        section, line_no, "integer field is invalid or out of range",
      )
  }
}

///|
fn parse_nonnegative_int64(
  text : String,
  section : String,
  line_no : Int,
) -> Int64 raise ComtradeError {
  let value = text.trim().to_owned()
  if value.is_empty() {
    raise Rejected(section, line_no, "empty timestamp tick field")
  }
  for c in value {
    if c < '0' || c > '9' {
      raise Rejected(
        section, line_no, "timestamp ticks must be nonnegative decimal integers",
      )
    }
  }
  @string.parse_int64(value, base=10) catch {
    _ => raise Rejected(section, line_no, "timestamp ticks exceed Int64 range")
  }
}

///|
fn parse_number(
  text : String,
  section : String,
  line_no : Int,
) -> Double raise ComtradeError {
  let value = text.trim().to_owned()
  if value.is_empty() {
    raise Rejected(section, line_no, "empty floating-point field")
  }
  let mut has_digit = false
  for c in value {
    if c >= '0' && c <= '9' {
      has_digit = true
    } else if c != '+' && c != '-' && c != '.' && c != 'e' && c != 'E' {
      raise Rejected(section, line_no, "invalid decimal floating-point field")
    }
  }
  if !has_digit {
    raise Rejected(section, line_no, "floating-point field has no digits")
  }
  let number = @string.parse_double(value) catch {
    _ =>
      raise Rejected(
        section, line_no, "invalid or out-of-range floating-point field",
      )
  }
  if !finite(number) {
    raise Rejected(section, line_no, "floating-point field is non-finite")
  }
  number
}

///|
fn finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}
