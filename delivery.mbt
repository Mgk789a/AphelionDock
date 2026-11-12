///|
#derive(FromJson)
pub(all) struct OrderLine {
  id : String
  supplier : String
  due : String
  units : Int32
}

///|
#derive(FromJson)
pub(all) struct Receipt {
  id : String
  line_id : String
  received_on : String
  units : Int32
}

///|
#derive(FromJson)
pub(all) struct ReviewInput {
  due_from : String
  due_to : String
  as_of : String
  lines : Array[OrderLine]
  receipts : Array[Receipt]
}

///|
#derive(Eq, ToJson)
pub(all) enum DeliveryStatus {
  OnTime
  FilledLate
  OpenOverdue
}

///|
#derive(ToJson)
pub(all) struct LineReview {
  id : String
  supplier : String
  due : String
  ordered : Int32
  on_time_units : Int32
  received_units : Int32
  outstanding : Int32
  excess : Int64
  receipt_ids : Array[String]
  status : DeliveryStatus
  filled_on : String?
}

///|
#derive(ToJson)
pub(all) struct SupplierReview {
  supplier : String
  due_lines : Int32
  on_time_lines : Int32
  filled_late_lines : Int32
  open_overdue_lines : Int32
}

///|
#derive(ToJson)
pub(all) struct Review {
  due_from : String
  due_to : String
  as_of : String
  lines : Array[LineReview]
  suppliers : Array[SupplierReview]
}

///|
#derive(Debug)
pub suberror InputError {
  Invalid(String)
}

///|
priv struct ReceiptTotals {
  mut on_time : Int64
  mut received : Int64
  receipts : Array[Receipt]
}

///|
priv struct SupplierCounts {
  mut on_time : Int32
  mut late : Int32
  mut open : Int32
}

///|
/// Dates are canonical YYYY-MM-DD, so chronological ordering is lexical.
fn is_date(value : String) -> Bool {
  if value.length() != 10 || value[4] != '-' || value[7] != '-' {
    return false
  }
  for i in 0..<10 {
    if i != 4 && i != 7 && (value[i] < '0' || value[i] > '9') {
      return false
    }
  }
  let year = date_part(value, 0, 4)
  let month = date_part(value, 5, 7)
  let day = date_part(value, 8, 10)
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let days = match month {
    2 => if leap { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    _ => 0
  }
  year > 0 && day > 0 && day <= days
}

///|
fn date_part(value : String, start : Int32, end : Int32) -> Int32 {
  let mut number = 0
  for i in start..<end {
    number = number * 10 + value[i].to_int() - 48
  }
  number
}

///|
fn valid_id(value : String) -> Bool {
  let trimmed = value.trim()
  !trimmed.is_empty() && trimmed.to_owned() == value
}

///|

///|
/// Return the first date the cumulative accepted quantity reached the order.
fn first_fill_date(receipts : Array[Receipt], ordered : Int64) -> String? {
  receipts.sort_by((a, b) => a.received_on.compare(b.received_on))
  let mut received = 0L
  for receipt in receipts {
    received += receipt.units.to_int64()
    if received >= ordered {
      return Some(receipt.received_on)
    }
  }
  None
}

///|
/// Review a closed cohort of order lines at the end of the as-of date.
pub fn review(input : ReviewInput) -> Review raise InputError {
  if !is_date(input.due_from) || !is_date(input.due_to) || !is_date(input.as_of) {
    raise Invalid("due_from, due_to and as_of must be valid YYYY-MM-DD dates")
  }
  if input.due_from > input.due_to || input.due_to > input.as_of {
    raise Invalid("required ordering: due_from <= due_to <= as_of")
  }
  let orders : Map[String, OrderLine] = Map([])
  let totals : Map[String, ReceiptTotals] = Map([])
  for line in input.lines {
    if !valid_id(line.id) ||
      !valid_id(line.supplier) ||
      !is_date(line.due) ||
      line.units <= 0 {
      raise Invalid("invalid order line: \{line.id}")
    }
    if orders.contains(line.id) {
      raise Invalid("duplicate order line: \{line.id}")
    }
    orders[line.id] = line
    if line.due >= input.due_from && line.due <= input.due_to {
      totals[line.id] = { on_time: 0L, received: 0L, receipts: [], }
    }
  }
  let receipt_ids : Set[String] = Set([])
  for receipt in input.receipts {
    if !valid_id(receipt.id) ||
      !is_date(receipt.received_on) ||
      receipt.units <= 0 {
      raise Invalid("invalid receipt: \{receipt.id}")
    }
    if receipt_ids.contains(receipt.id) {
      raise Invalid("duplicate receipt: \{receipt.id}")
    }
    receipt_ids.add(receipt.id)
    let line = match orders.get(receipt.line_id) {
      Some(line) => line
      None =>
        raise Invalid(
          "receipt \{receipt.id} references an unknown order line: \{receipt.line_id}",
        )
    }
    if receipt.received_on <= input.as_of {
      if totals.get(line.id) is Some(total) {
        total.received += receipt.units.to_int64()
        if receipt.received_on <= line.due {
          total.on_time += receipt.units.to_int64()
        }
        total.receipts.push(receipt)
      }
    }
  }
  let lines : Array[LineReview] = []
  let counts : Map[String, SupplierCounts] = Map([])
  for line in input.lines {
    guard totals.get(line.id) is Some(total) else { continue }
    let ordered = line.units.to_int64()
    let received = total.received.min(ordered).to_int()
    let on_time = total.on_time.min(ordered).to_int()
    let status = if on_time == line.units {
      OnTime
    } else if received == line.units {
      FilledLate
    } else {
      OpenOverdue
    }
    let count = match counts.get(line.supplier) {
      Some(count) => count
      None => {
        let count = { on_time: 0, late: 0, open: 0, }
        counts[line.supplier] = count
        count
      }
    }
    match status {
      OnTime => count.on_time += 1
      FilledLate => count.late += 1
      OpenOverdue => count.open += 1
    }
    let ids = total.receipts.map(receipt => receipt.id)
    ids.sort()
    lines.push({
      id: line.id,
      supplier: line.supplier,
      due: line.due,
      ordered: line.units,
      on_time_units: on_time,
      received_units: received,
      outstanding: line.units - received,
      excess: (total.received - ordered).max(0L),
      receipt_ids: ids,
      filled_on: if received == line.units {
        first_fill_date(total.receipts, ordered)
      } else {
        None
      },
      status,
    })
  }
  lines.sort_by((a, b) => a.id.compare(b.id))
  let suppliers : Array[SupplierReview] = []
  for supplier, count in counts {
    suppliers.push({
      supplier,
      due_lines: count.on_time + count.late + count.open,
      on_time_lines: count.on_time,
      filled_late_lines: count.late,
      open_overdue_lines: count.open,
    })
  }
  suppliers.sort_by((a, b) => a.supplier.compare(b.supplier))
  {
    due_from: input.due_from,
    due_to: input.due_to,
    as_of: input.as_of,
    lines,
    suppliers,
  }
}

///|
pub extend OrderLine with @json.FromJson::{from_json}

///|
pub extend Receipt with @json.FromJson::{from_json}

///|
pub extend ReviewInput with @json.FromJson::{from_json}

///|
pub extend DeliveryStatus with Eq::{equal, not_equal}

///|
pub extend DeliveryStatus with ToJson::{to_json}

///|
pub extend LineReview with ToJson::{to_json}

///|
pub extend SupplierReview with ToJson::{to_json}

///|
pub extend Review with ToJson::{to_json}

///|
pub extend InputError with Debug::{to_repr}
