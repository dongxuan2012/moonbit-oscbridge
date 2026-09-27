///|
/// Select samples in `[start_seconds, end_seconds)`. A zero-width interval is
/// valid and returns an empty caller-owned snapshot. The row and shared
/// channel-value budgets are checked before output arrays are copied.
pub fn Recording::window(
  self : Recording,
  start_seconds : Double,
  end_seconds : Double,
  max_rows? : Int = 10000,
) -> Window raise ComtradeError {
  if !finite(start_seconds) ||
    !finite(end_seconds) ||
    start_seconds > end_seconds {
    raise Rejected("window", 0, "window bounds must be finite and ordered")
  }
  if max_rows <= 0 || max_rows > 200000 {
    raise Rejected("window", 0, "max_rows must be in 1..200000")
  }
  let mut selected_count = 0
  for sample in self.rows {
    if sample.time_seconds >= start_seconds && sample.time_seconds < end_seconds {
      selected_count += 1
    }
  }
  if selected_count > max_rows {
    raise Rejected(
      "window", 0, "selected rows exceed max_rows; no truncation performed",
    )
  }
  let total_channels = self.analog.length() + self.digital.length()
  if selected_count * total_channels > 2000000 {
    raise Rejected(
      "capacity", 0, "window exceeds shared 2,000,000 channel-value budget",
    )
  }
  let samples : Array[Sample] = []
  for sample in self.rows {
    if sample.time_seconds >= start_seconds && sample.time_seconds < end_seconds {
      samples.push({
        sample_number: sample.sample_number,
        raw_ticks: sample.raw_ticks,
        time_seconds: sample.time_seconds,
        analog_raw: sample.analog_raw.copy(),
        status: sample.status.copy(),
      })
    }
  }
  {
    start_seconds,
    end_seconds,
    analog_channels: self.analog.copy(),
    status_channels: self.digital.copy(),
    samples,
  }
}
