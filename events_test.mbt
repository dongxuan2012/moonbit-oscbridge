///|
test "event search uses the real predecessor even outside the selected window" {
  let r = @oscbridge.parse(
    fixture_cfg("1000", 4, "-100", "100", "0", "1"),
    "1,0,3,1\n2,1000,4,0\n3,2000,5,0\n4,3000,6,1",
  )
  let events = r.status_transitions(0.0, 1.0)
  assert_eq(events.map(e => e.sample_number), [2, 4])
  assert_true(events[0].before)
  assert_false(events[0].after)
  assert_eq(r.status_transitions(0.001, 0.003).map(e => e.sample_number), [2])
  assert_eq(r.status_transitions(0.001, 0.001).length(), 0)
  assert_true(
    try {
      ignore(r.status_transitions(0.0, 1.0, max_events=1))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "event context verifies identity and rejects clipping and false events" {
  let r = @oscbridge.parse(
    fixture_cfg("1000", 4, "-100", "100", "0", "1"),
    "1,0,3,0\n2,1000,4,1\n3,2000,5,1\n4,3000,6,0",
  )
  assert_eq(r.transition_window(1, 2, 1, 1).samples.map(s => s.sample_number), [
    1, 2, 3,
  ])
  assert_eq(r.transition_window(1, 4, 0, 0).samples.map(s => s.sample_number), [
    4,
  ])
  for
    args in [
      (9, 2, 0, 0),
      (1, 1, 0, 0),
      (1, 3, 0, 0),
      (1, 2, 2, 0),
      (1, 4, 0, 1),
      (1, 2, -1, 0),
    ] {
    let (channel, sample, before, after) = args
    assert_true(
      try {
        ignore(r.transition_window(channel, sample, before, after))
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      ignore(r.transition_window(1, 2, 1, 1, max_rows=2))
      false
    } catch {
      _ => true
    },
  )
  let result = r.transition_window(1, 2, 1, 1)
  result.samples[0].status[0] = true
  assert_false(r.transition_window(1, 2, 1, 1).samples[0].status[0])
}
