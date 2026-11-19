///|
priv struct CsvTable {
  name : String
  columns : Array[Int32]
  width : Int32
  rows : Array[Array[String]]
}

///|
fn CsvTable::load(
  name : String,
  source : String,
  required : Array[String],
) -> CsvTable raise CsvError {
  let rows = parse_csv(source) catch {
    InvalidCsv(message) => raise InvalidCsv("\{name}: \{message}")
  }
  guard rows is [header, ..] else {
    raise InvalidCsv("\{name}: missing header")
  }
  let indices : Map[String, Int32] = Map([])
  for index, column in header {
    if column.is_empty() || indices.contains(column) {
      raise InvalidCsv(
        "\{name}: empty or duplicate column at position \{index + 1}",
      )
    }
    indices[column] = index
  }
  let columns : Array[Int32] = []
  for key in required {
    guard indices.get(key) is Some(index) else {
      raise InvalidCsv("\{name}: missing column \{key}")
    }
    columns.push(index)
  }
  { name, columns, width: header.length(), rows, }
}

///|
fn CsvTable::read_records(
  self : CsvTable,
  consume : (Array[String], Int32) -> Unit raise CsvError,
) -> Unit raise CsvError {
  for index, row in self.rows {
    if index == 0 {
      continue
    }
    let record = index + 1
    if row.length() != self.width {
      raise InvalidCsv(
        "\{self.name} record \{record}: expected \{self.width} fields, got \{row.length()}",
      )
    }
    consume(self.columns.map(column => row[column]), record)
  }
}

///|
fn csv_units(
  name : String,
  record : Int32,
  value : String,
) -> Int32 raise CsvError {
  if value.is_empty() {
    raise InvalidCsv("\{name} record \{record}: units is empty")
  }
  let mut units = 0
  for digit in value {
    if digit < '0' || digit > '9' {
      raise InvalidCsv(
        "\{name} record \{record}: units must contain decimal digits",
      )
    }
    let next = digit.to_int() - '0'.to_int()
    if units > (2147483647 - next) / 10 {
      raise InvalidCsv("{name} record {record}: units exceeds 2147483647")
    }
    units = units * 10 + next
  }
  if units == 0 {
    raise InvalidCsv("\{name} record \{record}: units must be positive")
  }
  units
}

///|
fn decode_csv_ledger(
  orders_source : String,
  receipts_source : String,
  due_from : String,
  due_to : String,
  as_of : String,
) -> @dock.ReviewInput raise CsvError {
  let orders = CsvTable::load("orders", orders_source, [
    "id", "supplier", "due", "units",
  ])
  let arrivals = CsvTable::load("receipts", receipts_source, [
    "id", "line_id", "received_on", "units",
  ])
  let lines : Array[@dock.OrderLine] = []
  let receipts : Array[@dock.Receipt] = []
  orders.read_records((cells, record) => {
    lines.push({
      id: cells[0],
      supplier: cells[1],
      due: cells[2],
      units: csv_units("orders", record, cells[3]),
    })
  })
  arrivals.read_records((cells, record) => {
    receipts.push({
      id: cells[0],
      line_id: cells[1],
      received_on: cells[2],
      units: csv_units("receipts", record, cells[3]),
    })
  })
  { due_from, due_to, as_of, lines, receipts, }
}
