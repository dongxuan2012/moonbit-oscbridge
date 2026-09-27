///|
extern "js" fn fail_bytes(message : String) -> Bytes =
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
