///|
test "ledger quantities cannot round to integers during JSON decoding" {
  let source =
    #|{"due_from":"2026-11-01","due_to":"2026-11-30","as_of":"2026-11-30",
    #|"lines":[{"id":"A","supplier":"North","due":"2026-11-10","units":100.000000000000000001}],"receipts":[]}
  let outcome = Ok(decode_ledger(source)) catch { error => Err(error) }
  guard outcome is Err(BadQuantity(message)) else {
    fail("expected exact quantity rejection")
  }
  assert_eq(message, "lines[0].units must be written as a JSON integer")
}
