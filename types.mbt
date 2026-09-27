///|
/// Fail-closed parse, bounds, or window error. Line is one-based for source
/// errors and zero for API-argument errors.
pub suberror ComtradeError {
  Rejected(String, Int, String)
} derive(@debug.Debug)

///|
/// Analog CFG metadata. `scaled` yields a*raw+b on the side declared by
/// `pors`; it never applies a primary/secondary ratio conversion. Raw lexemes
/// remain available for audit and output metadata.
pub(all) struct AnalogChannel {
  number : Int
  number_raw : String
  name : String
  phase : String
  circuit : String
  unit : String
  scale_a : Double
  scale_a_raw : String
  offset_b : Double
  offset_b_raw : String
  minimum : Double
  minimum_raw : String
  maximum : Double
  maximum_raw : String
  primary : Double
  primary_raw : String
  secondary : Double
  secondary_raw : String
  pors : String
  cfg_line_raw : String
}

///|
pub fn AnalogChannel::scaled(
  self : AnalogChannel,
  raw : Double,
) -> Double raise ComtradeError {
  let value = self.scale_a * raw + self.offset_b
  if raw.is_nan() || raw.is_inf() || value.is_nan() || value.is_inf() {
    raise Rejected("analog", 0, "raw/scaled analog value is non-finite")
  }
  if raw < self.minimum || raw > self.maximum {
    raise Rejected("analog", 0, "raw analog value outside CFG min/max")
  }
  value
}

///|
/// Digital/status CFG metadata. The profile admits only binary values 0 and 1.
pub(all) struct StatusChannel {
  number : Int
  number_raw : String
  name : String
  phase : String
  circuit : String
  initial_value : Int
  normal_state_raw : String
  cfg_line_raw : String
}

///|
/// One data row. Instances returned by `Recording::window` own fresh value
/// arrays and do not alias the recording's internal buffers.
pub(all) struct Sample {
  sample_number : Int
  raw_ticks : Int64
  time_seconds : Double
  analog_raw : Array[Double]
  status : Array[Bool]
}

///|
/// A caller-owned snapshot for a left-closed, right-open interval.
pub(all) struct Window {
  start_seconds : Double
  end_seconds : Double
  analog_channels : Array[AnalogChannel]
  status_channels : Array[StatusChannel]
  samples : Array[Sample]
}

///|
/// A checked single-rate ASCII COMTRADE profile. Array storage is explicitly
/// private; getters return detached metadata and windows contain deep copies.
pub struct Recording {
  priv station_name : String
  priv device_id : String
  priv revision : Int
  priv nominal_frequency_hz : Double
  priv sampling_rate_hz : Double
  priv time_multiplier : Double
  priv start_datetime_raw : String
  priv trigger_datetime_raw : String
  priv analog : Array[AnalogChannel]
  priv digital : Array[StatusChannel]
  priv rows : Array[Sample]
}

///|
pub fn Recording::analog_channels(self : Recording) -> Array[AnalogChannel] {
  self.analog.copy()
}

///|
pub fn Recording::status_channels(self : Recording) -> Array[StatusChannel] {
  self.digital.copy()
}

///|
pub fn Recording::sample_count(self : Recording) -> Int {
  self.rows.length()
}

///|
pub fn Recording::total_channels(self : Recording) -> Int {
  self.analog.length() + self.digital.length()
}

///|
pub fn Recording::revision(self : Recording) -> Int {
  self.revision
}

///|
pub fn Recording::station_name(self : Recording) -> String {
  self.station_name
}

///|
pub fn Recording::device_id(self : Recording) -> String {
  self.device_id
}

///|
pub fn Recording::nominal_frequency_hz(self : Recording) -> Double {
  self.nominal_frequency_hz
}

///|
pub fn Recording::sampling_rate_hz(self : Recording) -> Double {
  self.sampling_rate_hz
}

///|
pub fn Recording::time_multiplier(self : Recording) -> Double {
  self.time_multiplier
}

///|
pub fn Recording::start_datetime_raw(self : Recording) -> String {
  self.start_datetime_raw
}

///|
pub fn Recording::trigger_datetime_raw(self : Recording) -> String {
  self.trigger_datetime_raw
}
