///|
#derive(Debug)
priv suberror LedgerJsonError {
  BadJson
  BadQuantity(String)
}

///|
fn decode_ledger(source : StringView) -> @dock.ReviewInput raise {
  let value = @json.parse(
    source,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ => raise BadJson
  }
  match value {
    Object(fields) => {
      validate_quantity_tokens(fields, "lines")
      validate_quantity_tokens(fields, "receipts")
    }
    _ => ()
  }
  @json.from_json(value)
}

///|
fn validate_quantity_tokens(
  fields : Map[String, Json],
  key : String,
) -> Unit raise LedgerJsonError {
  guard fields.get(key) is Some(Array(rows)) else { return }
  for index, row in rows {
    guard row is Object(record) &&
      record.get("units") is Some(Number(_, repr=Some(token))) else {
      continue
    }
    if token.contains(".") || token.contains("e") || token.contains("E") {
      raise BadQuantity(
        "\{key}[\{index}].units must be written as a JSON integer",
      )
    }
  }
}
