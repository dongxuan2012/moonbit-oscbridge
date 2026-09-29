///|
/// An observed change between adjacent DAT samples, not a protection diagnosis.
pub(all) struct StatusTransition {
  channel_number : Int
  sample_number : Int
  previous_sample_number : Int
  time_seconds : Double
  before : Bool
  after : Bool
} derive(@debug.Debug, Eq, ToJson)

///|
pub extend StatusTransition with @debug.Debug::{to_repr}

///|
pub extend StatusTransition with Eq::{equal, not_equal}

///|
pub extend StatusTransition with ToJson::{to_json}

///|
/// List observed status edges in [start,end), ordered by sample then CFG order.
/// The first DAT sample has no predecessor and is never invented as an edge.
/// Search includes the predecessor outside the time window when available.
pub fn Recording::status_transitions(
  self : Recording,
  start_seconds : Double,
  end_seconds : Double,
  max_events? : Int = 1000,
) -> Array[StatusTransition] raise ComtradeError {
  if !finite(start_seconds) ||
    !finite(end_seconds) ||
    start_seconds > end_seconds {
    raise Rejected("events", 0, "event bounds must be finite and ordered")
  }
  if max_events < 1 || max_events > 10000 {
    raise Rejected("events", 0, "max_events must be in 1..10000")
  }
  let events : Array[StatusTransition] = []
  for i in 1..<self.rows.length() {
    let row = self.rows[i]
    if row.time_seconds < start_seconds || row.time_seconds >= end_seconds {
      continue
    }
    let previous = self.rows[i - 1]
    for j, channel in self.digital {
      if previous.status[j] != row.status[j] {
        if events.length() >= max_events {
          raise Rejected(
            "events",
            row.sample_number,
            "event budget exceeded; no truncation",
          )
        }
        events.push({
          channel_number: channel.number,
          sample_number: row.sample_number,
          previous_sample_number: previous.sample_number,
          time_seconds: row.time_seconds,
          before: previous.status[j],
          after: row.status[j],
        })
      }
    }
  }
  events
}

///|
/// Select an exact row context around a verified status edge. Insufficient
/// context rejects instead of clipping. Channel numbers are CFG IDs, not indices.
pub fn Recording::transition_window(
  self : Recording,
  channel_number : Int,
  sample_number : Int,
  before_rows : Int,
  after_rows : Int,
  max_rows? : Int = 10000,
) -> Window raise ComtradeError {
  if before_rows < 0 ||
    before_rows > 200000 ||
    after_rows < 0 ||
    after_rows > 200000 ||
    max_rows < 1 ||
    max_rows > 200000 ||
    before_rows + after_rows + 1 > max_rows {
    raise Rejected("events", 0, "invalid context or row budget")
  }
  if sample_number < 2 || sample_number > self.rows.length() {
    raise Rejected("events", 0, "edge must have a real predecessor")
  }
  let mut channel_index = -1
  for i, channel in self.digital {
    if channel.number == channel_number {
      channel_index = i
    }
  }
  let index = sample_number - 1
  if channel_index < 0 ||
    self.rows[index - 1].status[channel_index] ==
    self.rows[index].status[channel_index] {
    raise Rejected(
      "events", sample_number, "no observed edge for this channel and sample",
    )
  }
  let first = index - before_rows
  let last = index + after_rows
  if first < 0 || last >= self.rows.length() {
    raise Rejected(
      "events", sample_number, "requested context is unavailable; no clipping",
    )
  }
  let end = if last + 1 < self.rows.length() {
    self.rows[last + 1].time_seconds
  } else {
    self.rows[last].time_seconds + 1.0 / self.sampling_rate_hz
  }
  if !finite(end) || end <= self.rows[last].time_seconds {
    raise Rejected(
      "events", sample_number, "exclusive end cannot be represented",
    )
  }
  self.window(self.rows[first].time_seconds, end, max_rows~)
}
