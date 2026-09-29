///|
extern "js" fn fail_bytes(message : String) -> Bytes =
  #| (message) => { throw new Error(message); }

///|
extern "js" fn fail_text(message : String) -> String =
  #| (message) => { throw new Error(message); }

///|
/// Thin JS boundary. File reads and exclusive output publication stay in Node.
pub fn export_arrow_ipc(
  cfg : String,
  dat : String,
  start_seconds : Double,
  end_seconds : Double,
  max_rows : Int,
) -> Bytes {
  try {
    let recording = @comtrade.parse(cfg, dat)
    @adapter.write_window(recording, start_seconds, end_seconds, max_rows)
  } catch {
    error => fail_bytes(@debug.to_string(error))
  }
}

///|
fn main {
  ()
}

///|
pub fn status_events(
  cfg : String,
  dat : String,
  start : Double,
  end : Double,
  limit : Int,
) -> String {
  @comtrade.parse(cfg, dat)
  .status_transitions(start, end, max_events=limit)
  .to_json()
  .stringify() catch {
    error => fail_text(@debug.to_string(error))
  }
}

///|
pub fn export_transition_ipc(
  cfg : String,
  dat : String,
  channel : Int,
  sample : Int,
  before : Int,
  after : Int,
  limit : Int,
) -> Bytes {
  @adapter.write_transition_window(
    @comtrade.parse(cfg, dat),
    channel,
    sample,
    before,
    after,
    limit,
  ) catch {
    error => fail_bytes(@debug.to_string(error))
  }
}
