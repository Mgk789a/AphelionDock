///|
/// Escape a text field for spreadsheet import, including formula-like prefixes.
fn spreadsheet_text(value : String) -> String {
  match value.trim_start().to_owned().get_char(0) {
    Some('=' | '+' | '-' | '@') => "'" + value
    _ => value
  }
}

///|
fn csv_record(out : StringBuilder, fields : Array[String]) -> Unit {
  for index, field in fields {
    if index > 0 {
      out.write_char(',')
    }
    out.write_char('"')
    for ch in field {
      if ch == '"' {
        out.write_char('"')
      }
      out.write_char(ch)
    }
    out.write_char('"')
  }
  out.write_char('\n')
}

///|
fn status_label(status : @dock.DeliveryStatus) -> String {
  match status {
    OnTime => "OnTime"
    FilledLate => "FilledLate"
    OpenOverdue => "OpenOverdue"
  }
}

///|
fn review_csv(report : @dock.Review) -> String {
  let out = StringBuilder()
  csv_record(out, [
    "order_line", "supplier", "due", "ordered", "on_time_units", "received_units",
    "outstanding", "excess", "filled_on", "status",
  ])
  for line in report.lines {
    csv_record(out, [
      spreadsheet_text(line.id),
      spreadsheet_text(line.supplier),
      line.due,
      line.ordered.to_string(),
      line.on_time_units.to_string(),
      line.received_units.to_string(),
      line.outstanding.to_string(),
      line.excess.to_string(),
      line.filled_on.unwrap_or(""),
      status_label(line.status),
    ])
  }
  out.to_string()
}

///|
fn follow_up_csv(report : @dock.FollowUp) -> String {
  let out = StringBuilder()
  csv_record(out, [
    "order_line", "supplier", "from_as_of", "to_as_of", "previous_status", "current_status",
    "outstanding_before", "outstanding_now", "excess_before", "excess_now", "new_receipt_ids_json",
  ])
  for change in report.changes {
    csv_record(out, [
      spreadsheet_text(change.id),
      spreadsheet_text(change.supplier),
      report.from_as_of,
      report.to_as_of,
      status_label(change.previous_status),
      status_label(change.current_status),
      change.outstanding_before.to_string(),
      change.outstanding_now.to_string(),
      change.excess_before.to_string(),
      change.excess_now.to_string(),
      Json::Json(change.new_receipt_ids).stringify(),
    ])
  }
  out.to_string()
}

///|
fn supplier_csv(report : @dock.Review) -> String {
  let out = StringBuilder()
  csv_record(out, [
    "supplier", "due_from", "due_to", "as_of", "due_lines", "on_time_lines", "filled_late_lines",
    "open_overdue_lines",
  ])
  for supplier in report.suppliers {
    csv_record(out, [
      spreadsheet_text(supplier.supplier),
      report.due_from,
      report.due_to,
      report.as_of,
      supplier.due_lines.to_string(),
      supplier.on_time_lines.to_string(),
      supplier.filled_late_lines.to_string(),
      supplier.open_overdue_lines.to_string(),
    ])
  }
  out.to_string()
}
