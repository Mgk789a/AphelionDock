///|
extern "js" fn print_error(message : String) = "(message) => console.error(message)"

///|
fn stop(message : String) -> Unit {
  print_error(message)
  @env.exit(2)
}

///|
fn main {
  guard @env.args() is [_, _, path] else {
    stop("Usage: moon run dock-review --target js -- <input.json>")
    return
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
  let report = @dock.review(input) catch {
    @dock.Invalid(message) => {
      stop(message)
      return
    }
  }
  println(report.to_json().stringify(indent=2))
}
