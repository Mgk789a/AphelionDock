///|
priv enum CsvField {
  Start
  Plain
  Quoted
  Closed
}

///|
priv suberror CsvError {
  InvalidCsv(String)
}

///|
priv struct CsvReader {
  mut state : CsvField
  mut field : StringBuilder
  mut row : Array[String]
  rows : Array[Array[String]]
}

///|
fn CsvReader::end_field(self : CsvReader) -> Unit {
  self.row.push(self.field.to_string())
  self.field = StringBuilder()
  self.state = Start
}

///|
fn CsvReader::end_record(self : CsvReader) -> Unit {
  self.end_field()
  self.rows.push(self.row)
  self.row = []
}

///|
fn CsvReader::unexpected(self : CsvReader, reason : String) -> CsvError {
  let record = self.rows.length() + 1
  let field = self.row.length() + 1
  InvalidCsv("record \{record}, field \{field}: \{reason}")
}

///|
fn CsvReader::read_char(self : CsvReader, ch : Char) -> Unit raise CsvError {
  match (self.state, ch) {
    (Quoted, '"') => self.state = Closed
    (Quoted, _) => self.field.write_char(ch)
    (Closed, '"') => {
      self.field.write_char('"')
      self.state = Quoted
    }
    (_, ',') => self.end_field()
    (_, '\n' | '\r') => self.end_record()
    (Start, '"') => self.state = Quoted
    (Plain, '"') => raise self.unexpected("quote inside an unquoted field")
    (Closed, _) =>
      raise self.unexpected("expected a delimiter after closing quote")
    (Start | Plain, _) => {
      self.field.write_char(ch)
      self.state = Plain
    }
  }
}

///|
fn parse_csv(source : String) -> Array[Array[String]] raise CsvError {
  let reader = { state: Start, field: StringBuilder(), row: [], rows: [], }
  let mut skip_lf = false
  for ch in source {
    let skip = skip_lf && ch == '\n'
    skip_lf = ch == '\r' && !(reader.state is Quoted)
    if !skip {
      reader.read_char(ch)
    }
  }
  match reader.state {
    Quoted => raise reader.unexpected("unterminated quoted field")
    Start if reader.row.is_empty() => ()
    _ => reader.end_record()
  }
  reader.rows
}
