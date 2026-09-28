///|
/// Errors remain distinguishable across the thin JS file-host boundary.
pub(all) suberror ArrowExportError {
  Source(@comtrade.ComtradeError)
  Ipc(@moonarrow.ArrowError)
} derive(@debug.Debug)

///|
pub extend ArrowExportError with @debug.Debug::{to_repr}

///|
fn kv(key : String, value : String) -> @moonarrow.KeyValue {
  @moonarrow.KeyValue::{ key, value: Some(value), }
}

///|
fn channel_metadata(
  channel_id : String,
  channel_name : String,
  phase : String,
  circuit : String,
  cfg_unit : String,
  a : String,
  b : String,
  primary : String,
  secondary : String,
  pors : String,
  value_kind : String,
  unit : String,
  value_semantics : String,
  cfg_line_raw : String,
) -> Array[@moonarrow.KeyValue] {
  [
    kv("channel_id", channel_id),
    kv("channel_name", channel_name),
    kv("phase", phase),
    kv("circuit", circuit),
    kv("cfg_unit", cfg_unit),
    kv("a", a),
    kv("b", b),
    kv("primary", primary),
    kv("secondary", secondary),
    kv("pors", pors),
    kv("value_kind", value_kind),
    kv("unit", unit),
    kv("value_semantics", value_semantics),
    kv("cfg_line_raw", cfg_line_raw),
  ]
}

///|
fn channel_suffix(index : Int) -> String {
  let number = index + 1
  if number < 10 {
    "00\{number}"
  } else if number < 100 {
    "0\{number}"
  } else {
    "\{number}"
  }
}

///|
fn analog_field(
  channel_index : Int,
  channel : @comtrade.AnalogChannel,
  suffix : String,
  value_kind : String,
  unit : String,
  value_semantics : String,
) -> @moonarrow.Field {
  @moonarrow.Field::new(
    "analog_\{channel_suffix(channel_index)}_\{suffix}",
    @moonarrow.Float64,
    nullable=false,
    metadata=channel_metadata(
      channel.number_raw,
      channel.name,
      channel.phase,
      channel.circuit,
      channel.unit,
      channel.scale_a_raw,
      channel.offset_b_raw,
      channel.primary_raw,
      channel.secondary_raw,
      channel.pors,
      value_kind,
      unit,
      value_semantics,
      channel.cfg_line_raw,
    ),
  )
}

///|
fn status_field(
  channel_index : Int,
  channel : @comtrade.StatusChannel,
) -> @moonarrow.Field {
  @moonarrow.Field::new(
    "status_\{channel_suffix(channel_index)}",
    @moonarrow.Boolean,
    nullable=false,
    metadata=[
      kv("channel_id", channel.number_raw),
      kv("channel_name", channel.name),
      kv("phase", channel.phase),
      kv("circuit", channel.circuit),
      kv("unit", "boolean"),
      kv("value_kind", "status"),
      kv("value_semantics", "COMTRADE DAT 0/1 mapped to false/true"),
      kv("normal_state", channel.normal_state_raw),
      kv("cfg_line_raw", channel.cfg_line_raw),
    ],
  )
}

///|
fn schema_metadata(
  recording : @comtrade.Recording,
  start_seconds : Double,
  end_seconds : Double,
  row_count : Int,
) -> Array[@moonarrow.KeyValue] {
  [
    kv("comtrade.profile", "COMTRADE-\{recording.revision()} ASCII single-rate"),
    kv("comtrade.station_name", recording.station_name()),
    kv("comtrade.device_id", recording.device_id()),
    kv("comtrade.nominal_frequency_hz", "\{recording.nominal_frequency_hz()}"),
    kv("comtrade.sampling_rate_hz", "\{recording.sampling_rate_hz()}"),
    kv("comtrade.time_multiplier", "\{recording.time_multiplier()}"),
    kv("comtrade.sample_count_total", "\{recording.sample_count()}"),
    kv("comtrade.window_rows", "\{row_count}"),
    kv(
      "comtrade.analog_channel_count",
      "\{recording.analog_channels().length()}",
    ),
    kv(
      "comtrade.status_channel_count",
      "\{recording.status_channels().length()}",
    ),
    kv("comtrade.start_datetime_raw", recording.start_datetime_raw()),
    kv("comtrade.trigger_datetime_raw", recording.trigger_datetime_raw()),
    kv("comtrade.window_semantics", "[start,end)"),
    kv("comtrade.window_start_seconds", "\{start_seconds}"),
    kv("comtrade.window_end_seconds", "\{end_seconds}"),
    kv(
      "comtrade.time_coordinate", "relative seconds derived from DAT raw ticks and time multiplier; source timezone absent; no UTC claim",
    ),
    kv(
      "comtrade.analog_scaled_semantics", "CFG a*raw+b on the P/S-declared side; no primary/secondary ratio conversion",
    ),
    kv("comtrade.absolute_time_claim", "none"),
  ]
}

///|
fn build_ipc(
  recording : @comtrade.Recording,
  window : @comtrade.Window,
  start_seconds : Double,
  end_seconds : Double,
) -> Bytes raise ArrowExportError {
  let analog_channels = window.analog_channels
  let status_channels = window.status_channels
  let fields : Array[@moonarrow.Field] = [
    @moonarrow.Field::new("sample_number", @moonarrow.Int32, nullable=false, metadata=[
      kv("value_kind", "sample_identity"),
      kv("value_semantics", "original one-based COMTRADE DAT sample number"),
    ]),
    @moonarrow.Field::new("raw_ticks", @moonarrow.Int64, nullable=false, metadata=[
      kv("value_kind", "raw_tick"),
      kv("value_semantics", "original integer tick field from COMTRADE DAT"),
      kv("unit", "DAT tick"),
    ]),
    @moonarrow.Field::new(
      "relative_seconds",
      @moonarrow.Float64,
      nullable=false,
      metadata=[
        kv("value_kind", "relative_time"),
        kv("value_semantics", "DAT tick-derived seconds; no timezone/UTC claim"),
        kv("unit", "s"),
      ],
    ),
  ]
  for channel_index, channel in analog_channels {
    fields.push(
      analog_field(
        channel_index, channel, "raw", "raw", "raw-count", "parsed numeric COMTRADE DAT analog value before CFG a*raw+b; not a physical engineering value",
      ),
    )
    fields.push(
      analog_field(
        channel_index,
        channel,
        "scaled",
        "scaled",
        channel.unit,
        "CFG a*raw+b on the P/S-declared side; unit is the CFG engineering unit; no side conversion",
      ),
    )
  }
  for channel_index, channel in status_channels {
    fields.push(status_field(channel_index, channel))
  }

  let schema = @moonarrow.Schema::new(
    fields,
    metadata=schema_metadata(
      recording,
      start_seconds,
      end_seconds,
      window.samples.length(),
    ),
  )
  let columns : Array[@moonarrow.Column] = []
  let sample_numbers : Array[Int?] = []
  let raw_ticks : Array[Int64?] = []
  let relative_seconds : Array[Double?] = []
  for sample in window.samples {
    sample_numbers.push(Some(sample.sample_number))
    raw_ticks.push(Some(sample.raw_ticks))
    relative_seconds.push(Some(sample.time_seconds))
  }
  columns.push(@moonarrow.Int32s(sample_numbers))
  columns.push(@moonarrow.Int64s(raw_ticks))
  columns.push(@moonarrow.Float64s(relative_seconds))

  for channel_index, channel in analog_channels {
    let raw_values : Array[Double?] = []
    let scaled_values : Array[Double?] = []
    for sample in window.samples {
      let raw = sample.analog_raw[channel_index]
      let scaled = channel.scaled(raw) catch {
        error => raise ArrowExportError::Source(error)
      }
      raw_values.push(Some(raw))
      scaled_values.push(Some(scaled))
    }
    columns.push(@moonarrow.Float64s(raw_values))
    columns.push(@moonarrow.Float64s(scaled_values))
  }

  for channel_index, _channel in status_channels {
    let values : Array[Bool?] = []
    for sample in window.samples {
      values.push(Some(sample.status[channel_index]))
    }
    columns.push(@moonarrow.Booleans(values))
  }
  let batch = @moonarrow.RecordBatch::new(
    schema,
    columns,
    num_rows=window.samples.length(),
  ) catch {
    error => raise ArrowExportError::Ipc(error)
  }
  @moonarrow.write_file(schema, [batch]) catch {
    error => raise ArrowExportError::Ipc(error)
  }
}

///|
/// Convert one checked COMTRADE recording window into a single Arrow IPC file.
/// The JS host owns bounded file I/O and no-replacement publication.
pub fn write_window(
  recording : @comtrade.Recording,
  start_seconds : Double,
  end_seconds : Double,
  max_rows : Int,
) -> Bytes raise ArrowExportError {
  let window = recording.window(start_seconds, end_seconds, max_rows~) catch {
    error => raise ArrowExportError::Source(error)
  }
  // Column names use channel position, avoiding collisions between equal CFG
  // display names while field metadata retains the actual channel identity.
  build_ipc(recording, window, start_seconds, end_seconds)
}
