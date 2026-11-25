///|
fn entry(
  id : String,
  date : String,
  kind : String,
  units? : Int32,
  reference? : String,
  due? : String,
) -> LedgerEvent {
  { id, line_id: "P", date, kind, units, reference, due, }
}

///|
fn audit(
  events : Array[LedgerEvent],
  as_of~ : String = "2026-11-18",
) -> ReplayLine raise InputError {
  replay({
    as_of,
    lines: [{ id: "P", supplier: "North", due: "2026-11-10", units: 100, }],
    events,
  }).lines[0]
}

///|
test "same ending balance can have distinct obligations and shortage history" {
  let a = entry("A", "2026-11-09", "amend_due", due="2026-11-12")
  let r1 = entry("R1", "2026-11-10", "receive", units=60)
  let r2 = entry("R2", "2026-11-12", "receive", units=40)
  let t = entry("T", "2026-11-13", "return", units=20, reference="R2")
  let x = entry("X", "2026-11-16", "reverse", reference="T")
  let original = audit([r1, r2])
  let adjusted = audit([a, r1, r2, t, x])
  assert_eq(original.net_received, adjusted.net_received)
  assert_eq(original.approved_due_result, "missed")
  assert_eq(adjusted.original_due_net, Some(60L))
  assert_eq(adjusted.approved_due_net, Some(100L))
  assert_eq(adjusted.approved_due_result, "met")
  assert_eq(adjusted.reopen_count, 1)
  assert_eq(adjusted.currently_filled_since, Some("2026-11-16"))
  let before_reversal = audit([a, r1, r2, t, x], as_of="2026-11-13")
  assert_eq(before_reversal.outstanding, 20L)
  assert_eq(before_reversal.approved_due_result, "met")
  assert_eq(before_reversal.trail.length(), 4)
  let pending = audit([a, r1, r2, t, x], as_of="2026-11-10")
  assert_eq(pending.original_due_result, "missed")
  assert_eq(pending.approved_due_result, "pending")
}

///|
test "due-day cutoff sees all postings and a receipt reversal preserves history" {
  let receive = entry("R", "2026-11-10", "receive", units=100)
  let returned = entry("T", "2026-11-10", "return", units=10, reference="R")
  let undo_return = entry("X", "2026-11-11", "reverse", reference="T")
  let undo_receipt = entry("Y", "2026-11-11", "reverse", reference="R")
  let report = audit([receive, returned, undo_return, undo_receipt])
  assert_eq(report.original_due_net, Some(90L))
  assert_eq(report.net_received, 0L)
  assert_eq(report.reopen_count, 2)
}

///|
fn expect_invalid(events : Array[LedgerEvent], reason : String) -> Unit raise {
  let result = Ok(audit(events)) catch { e => Err(e) }
  guard result is Err(Invalid(message)) else { fail("expected rejection") }
  assert_true(message.contains(reason))
}

///|
test "reject causally inconsistent ledger entries" {
  let r = entry("R", "2026-11-10", "receive", units=100)
  let t = entry("T", "2026-11-11", "return", units=60, reference="R")
  expect_invalid(
    [r, t, entry("T2", "2026-11-11", "return", units=41, reference="R")],
    "available quantity",
  )
  expect_invalid(
    [r, t, entry("X", "2026-11-11", "reverse", reference="R")],
    "reverse active returns",
  )
  let undo = entry("X", "2026-11-11", "reverse", reference="T")
  expect_invalid(
    [r, t, undo, entry("Y", "2026-11-11", "reverse", reference="T")],
    "unreversed",
  )
  expect_invalid(
    [r, entry("A", "2026-11-11", "amend_due", due="2026-11-12")],
    "active due date",
  )
  expect_invalid(
    [r, entry("A", "2026-12-01", "receive", units=1), t],
    "nondecreasing",
  )
  expect_invalid([r, { ..t, line_id: "unknown", }], "unknown order line")
  expect_invalid([r, { ..t, id: "R", }], "duplicate event id")
}
