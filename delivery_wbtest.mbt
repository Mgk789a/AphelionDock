///|
test "closed cohort distinguishes split on-time, late and open lines" {
  let result = review({
    due_from: "2026-11-01",
    due_to: "2026-11-30",
    as_of: "2026-11-30",
    lines: [
      { id: "D", supplier: "North", due: "2026-12-01", units: 10, },
      { id: "C", supplier: "South", due: "2026-11-20", units: 10, },
      { id: "B", supplier: "North", due: "2026-11-20", units: 10, },
      { id: "A", supplier: "North", due: "2026-11-01", units: 10, },
    ],
    receipts: [
      { id: "R6", line_id: "C", received_on: "2026-12-01", units: 6, },
      { id: "R5", line_id: "C", received_on: "2026-11-25", units: 4, },
      { id: "R4", line_id: "B", received_on: "2026-11-21", units: 8, },
      { id: "R3", line_id: "B", received_on: "2026-11-20", units: 4, },
      { id: "R2", line_id: "A", received_on: "2026-11-01", units: 6, },
      { id: "R1", line_id: "A", received_on: "2026-10-31", units: 4, },
    ],
  })
  assert_eq(result.lines.map(line => line.id), ["A", "B", "C"])
  assert_true(result.lines[0].status == OnTime)
  assert_eq(result.lines[0].receipt_ids, ["R1", "R2"])
  assert_true(result.lines[1].status == FilledLate)
  inspect(result.lines[1].on_time_units, content="4")
  inspect(result.lines[1].received_units, content="10")
  inspect(result.lines[1].excess, content="2")
  assert_true(result.lines[2].status == OpenOverdue)
  inspect(result.lines[2].outstanding, content="6")
  assert_eq(result.lines[2].receipt_ids, ["R5"])
  inspect(result.suppliers[0].due_lines, content="2")
  inspect(result.suppliers[0].on_time_lines, content="1")
  inspect(result.suppliers[0].filled_late_lines, content="1")
  inspect(result.suppliers[1].open_overdue_lines, content="1")
}

///|
test "receipts without an order line fail even after the cutoff" {
  let result = Ok(
    review({
      due_from: "2026-11-01",
      due_to: "2026-11-30",
      as_of: "2026-11-30",
      lines: [],
      receipts: [
        { id: "R1", line_id: "missing", received_on: "2026-12-01", units: 1, },
      ],
    }),
  ) catch {
    error => Err(error)
  }
  guard result is Err(Invalid(message)) else {
    fail("expected a missing line error")
  }
  inspect(
    message,
    content="receipt R1 references an unknown order line: missing",
  )
}

///|
test "a duplicate receipt cannot make an order appear fulfilled" {
  let line = { id: "A", supplier: "North", due: "2026-11-01", units: 10, }
  let receipt = { id: "R1", line_id: "A", received_on: "2026-11-01", units: 5, }
  let result = Ok(
    review({
      due_from: "2026-11-01",
      due_to: "2026-11-30",
      as_of: "2026-11-30",
      lines: [line],
      receipts: [receipt, receipt],
    }),
  ) catch {
    error => Err(error)
  }
  guard result is Err(Invalid(message)) else {
    fail("expected a duplicate receipt error")
  }
  inspect(message, content="duplicate receipt: R1")
}

///|
test "Gregorian date validation distinguishes leap years" {
  assert_true(is_date("2024-02-29"))
  assert_true(is_date("2000-02-29"))
  assert_false(is_date("2100-02-29"))
  assert_false(is_date("2026-11-31"))
  assert_false(is_date("2026-1-01"))
}

///|
test "an incomplete due window is rejected" {
  let result = Ok(
    review({
      due_from: "2026-11-01",
      due_to: "2026-11-30",
      as_of: "2026-11-29",
      lines: [],
      receipts: [],
    }),
  ) catch {
    error => Err(error)
  }
  guard result is Err(Invalid(message)) else {
    fail("expected a date window error")
  }
  inspect(message, content="required ordering: due_from <= due_to <= as_of")
}
