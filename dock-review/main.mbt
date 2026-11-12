///|
extern "js" fn print_error(message : String) = "(message) => console.error(message)"

///|
fn stop(message : String) -> Unit {
  print_error(message)
  @env.exit(2)
}

///|
fn main {
  let (path, follow_up_date) = match @env.args() {
    [_, _, path] => (path, None)
    [_, _, path, "--follow-up", date] => (path, Some(date))
    _ => {
      stop(
        "Usage: moon run dock-review --target js -- <input.json> [--follow-up YYYY-MM-DD]",
      )
      return
    }
  }
  let source = @fs.read_file_to_string(path) catch {
    _ => {
      stop("Could not read the input file as UTF-8.")
      return
    }
  }
  let value = @json.parse(source, reject_duplicate_keys=true) catch {
    _ => {
      stop("Invalid JSON. Check syntax and duplicate keys.")
      return
    }
  }
  let input : @dock.ReviewInput = @json.from_json(value) catch {
    error => {
      stop("Invalid input fields: \{Repr(error)}")
      return
    }
  }
  let report = try {
    match follow_up_date {
      Some(date) => @dock.follow_up(input, date).to_json()
      None => @dock.review(input).to_json()
    }
  } catch {
    @dock.Invalid(message) => {
      stop(message)
      return
    }
  }
  println(report.stringify(indent=2))
}
