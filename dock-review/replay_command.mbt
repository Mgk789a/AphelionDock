///|
fn replay_json(path : String) -> String raise {
  let source = read_ledger_file(path, "event ledger")
  let value = @json.parse(
    source,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ => raise BadJson
  }
  if value is Object(fields) {
    validate_quantity_tokens(fields, "lines")
    validate_quantity_tokens(fields, "events")
  }
  let input : @dock.ReplayInput = @json.from_json(value)
  @dock.replay(input).to_json().stringify(indent=2) + "\n"
}
