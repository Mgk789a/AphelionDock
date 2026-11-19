///|
test "CSV parser handles quoted commas, doubled quotes, and CRLF" {
  let rows = parse_csv("id,supplier\r\nP1,\"北桥, \"\"一部\"\"\"\r\n")
  assert_eq(rows, [["id", "supplier"], ["P1", "北桥, \"一部\""]])
  assert_eq(parse_csv("a,\"two\r\nlines\",\n"), [["a", "two\r\nlines", ""]])
  let invalid = Ok(parse_csv("a,\"x\"z")) catch { e => Err(e) }
  assert_true(invalid is Err(InvalidCsv(_)))
}

///|
test "CSV input supports reordered columns and rejects fractional quantities" {
  let orders = "supplier,units,id,due\nNorth,10,A,2026-11-10"
  let receipts = "id,line_id,received_on,units\nR,A,2026-11-12,10"
  let input = decode_csv_ledger(
    orders, receipts, "2026-11-01", "2026-11-30", "2026-11-30",
  )
  let review = @dock.review(input)
  assert_eq(review.lines[0].filled_on, Some("2026-11-12"))
  assert_true(review.lines[0].status is FilledLate)
  let invalid = Ok(
    decode_csv_ledger(
      orders,
      receipts + ".5",
      "2026-11-01",
      "2026-11-30",
      "2026-11-30",
    ),
  ) catch {
    e => Err(e)
  }
  guard invalid is Err(InvalidCsv(message)) else {
    fail("expected a CSV quantity error")
  }
  assert_eq(message, "receipts record 2: units must contain decimal digits")
}

///|
test "CSV output escapes formulas and preserves text with commas" {
  let out = StringBuilder()
  csv_record(out, [
    spreadsheet_text("=1+1"),
    spreadsheet_text("North, Branch"),
    "A\"B",
  ])
  assert_eq(parse_csv(out.to_string()), [["'=1+1", "North, Branch", "A\"B"]])
}
