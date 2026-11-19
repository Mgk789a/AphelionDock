///|
extern "js" fn print_error(message : String) = "(message) => console.error(message)"

///|
extern "js" fn write_report(message : String) = "(message) => process.stdout.write(message)"

///|
priv suberror CommandError {
  Usage(String)
  ReadFailed(String)
}

///|
priv enum LedgerSource {
  JsonFile(String)
  CsvFiles(String, String, String, String, String)
}

///|
priv enum OutputFormat {
  JsonOutput
  CsvLines
  CsvSuppliers
}

///|
priv struct Command {
  source : LedgerSource
  as_of : String?
  format : OutputFormat
}

///|
fn parse_command(args : Array[String]) -> Command raise CommandError {
  let (source, start) = match args {
    [_, _, "--csv", orders, receipts, from, to, as_of, ..] =>
      (CsvFiles(orders, receipts, from, to, as_of), 8)
    [_, _, path, ..] if !path.has_prefix("--") => (JsonFile(path), 3)
    _ =>
      raise Usage(
        "Expected a JSON ledger or --csv ORDERS RECEIPTS DUE_FROM DUE_TO AS_OF.",
      )
  }
  let mut as_of = None
  let mut format = JsonOutput
  for index = start; index < args.length(); index = index + 2 {
    guard index + 1 < args.length() else {
      raise Usage("Missing value for \{args[index]}.")
    }
    match (args[index], args[index + 1]) {
      ("--follow-up", date) if as_of is None => as_of = Some(date)
      ("--format", "csv") if format is JsonOutput => format = CsvLines
      ("--format", "supplier-csv") if format is JsonOutput =>
        format = CsvSuppliers
      _ => raise Usage("Invalid or repeated option \{args[index]}.")
    }
  }
  if as_of is Some(_) && format is CsvSuppliers {
    raise Usage("supplier-csv is available for a single observation date.")
  }
  { source, as_of, format, }
}

///|
fn read_ledger_file(path : String, label : String) -> String raise CommandError {
  let bytes = @fs.read_file_to_bytes(path) catch {
    _ => raise ReadFailed("Could not read the \{label} file.")
  }
  @utf8.decode(bytes.exact_view(), ignore_bom=true) catch {
    _ => raise ReadFailed("The \{label} file is not valid UTF-8.")
  }
}

///|
fn load_input(source : LedgerSource) -> @dock.ReviewInput raise {
  match source {
    JsonFile(path) => decode_ledger(read_ledger_file(path, "ledger"))
    CsvFiles(orders, receipts, from, to, as_of) => {
      let orders_text = read_ledger_file(orders, "orders")
      let receipts_text = read_ledger_file(receipts, "receipts")
      decode_csv_ledger(orders_text, receipts_text, from, to, as_of)
    }
  }
}

///|
fn execute(command : Command) -> String raise {
  let input = load_input(command.source)
  match command.as_of {
    Some(date) => {
      let report = @dock.follow_up(input, date)
      match command.format {
        CsvLines => follow_up_csv(report)
        _ => report.to_json().stringify(indent=2) + "\n"
      }
    }
    None => {
      let report = @dock.review(input)
      match command.format {
        JsonOutput => report.to_json().stringify(indent=2) + "\n"
        CsvLines => review_csv(report)
        CsvSuppliers => supplier_csv(report)
      }
    }
  }
}

///|
fn main {
  let output = execute(parse_command(@env.args())) catch {
    Usage(message) => {
      print_error(message)
      print_error(
        "Usage: dock-review <input.json> or --csv ORDERS RECEIPTS DUE_FROM DUE_TO AS_OF",
      )
      print_error("Options: --follow-up YYYY-MM-DD, --format csv|supplier-csv")
      @env.exit(2)
    }
    ReadFailed(message)
    | InvalidCsv(message)
    | BadQuantity(message)
    | @dock.Invalid(message) => {
      print_error(message)
      @env.exit(2)
    }
    BadJson => {
      print_error("Invalid JSON. Check syntax and duplicate keys.")
      @env.exit(2)
    }
    error => {
      print_error("Invalid input fields: \{Repr(error)}")
      @env.exit(2)
    }
  }
  write_report(output)
}
