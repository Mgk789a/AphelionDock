///|
/// An ordered ledger entry. The date is the posting date and array order
/// resolves same-day entries. References point to earlier entries on this line.
#derive(FromJson)
pub(all) struct LedgerEvent {
  id : String
  line_id : String
  date : String
  kind : String
  units : Int32?
  reference : String?
  due : String?
}

///|
#derive(FromJson)
pub(all) struct ReplayInput {
  as_of : String
  lines : Array[OrderLine]
  events : Array[LedgerEvent]
}

///|
#derive(ToJson)
pub struct ReplayStep {
  event_id : String
  date : String
  kind : String
  reference : String?
  approved_due : String
  net_received : Int64
  outstanding : Int64
}

///|
#derive(ToJson)
pub struct ReplayLine {
  id : String
  supplier : String
  original_due : String
  approved_due : String
  ordered : Int32
  net_received : Int64
  outstanding : Int64
  excess : Int64
  original_due_result : String
  approved_due_result : String
  original_due_net : Int64?
  approved_due_net : Int64?
  currently_filled_since : String?
  reopen_count : Int32
  trail : Array[ReplayStep]
}

///|
#derive(ToJson)
pub struct ReplayReport {
  as_of : String
  lines : Array[ReplayLine]
}

///|
pub extend LedgerEvent with @json.FromJson::{from_json}

///|
pub extend ReplayInput with @json.FromJson::{from_json}

///|
pub extend ReplayStep with ToJson::{to_json}

///|
pub extend ReplayLine with ToJson::{to_json}

///|
pub extend ReplayReport with ToJson::{to_json}

///|
priv struct PostedReceipt {
  units : Int64
  mut available : Int64
  mut reversed : Bool
}

///|
priv struct PostedReturn {
  receipt : PostedReceipt
  units : Int64
  mut reversed : Bool
}

///|
priv enum Reversible {
  ReceiptEntry(PostedReceipt)
  ReturnEntry(PostedReturn)
}

///|
priv struct ReplayState {
  line : OrderLine
  mut due : String
  mut net : Int64
  mut original_at_due : Int64?
  mut approved_at_due : Int64?
  mut filled_since : String?
  mut reopens : Int32
  posted : Map[String, Reversible]
  trail : Array[ReplayStep]
}

///|
fn LedgerEvent::invalid(self : LedgerEvent, reason : String) -> InputError {
  Invalid("event \{self.id} on \{self.line_id}: \{reason}")
}

///|
fn ReplayState::close_before(self : ReplayState, date : String) -> Unit {
  if self.original_at_due is None && self.line.due < date {
    self.original_at_due = Some(self.net)
  }
  if self.approved_at_due is None && self.due < date {
    self.approved_at_due = Some(self.net)
  }
}

///|
fn ReplayState::post(
  self : ReplayState,
  event : LedgerEvent,
) -> Unit raise InputError {
  self.close_before(event.date)
  let prior = self.net
  match (event.kind, event.units, event.reference, event.due) {
    ("receive", Some(units), None, None) if units > 0 => {
      let amount = units.to_int64()
      let receipt = { units: amount, available: amount, reversed: false, }
      self.posted[event.id] = ReceiptEntry(receipt)
      self.net += amount
    }
    ("return", Some(units), Some(reference), None) if units > 0 => {
      guard self.posted.get(reference) is Some(ReceiptEntry(receipt)) &&
        !receipt.reversed else {
        raise event.invalid(
          "return must reference an active receipt on the same line",
        )
      }
      let amount = units.to_int64()
      if amount > receipt.available {
        raise event.invalid(
          "return exceeds the referenced receipt's available quantity",
        )
      }
      receipt.available -= amount
      self.net -= amount
      self.posted[event.id] = ReturnEntry({
        receipt,
        units: amount,
        reversed: false,
      })
    }
    ("reverse", None, Some(reference), None) => self.reverse(event, reference)
    ("amend_due", None, None, Some(due)) => {
      if !is_date(due) ||
        due < event.date ||
        event.date > self.due ||
        due == self.due {
        raise event.invalid(
          "approval must be posted by the active due date and set a different due date on or after approval",
        )
      }
      self.due = due
    }
    _ =>
      raise event.invalid("invalid event kind, quantity or field combination")
  }
  let ordered = self.line.units.to_int64()
  if prior < ordered && self.net >= ordered {
    self.filled_since = Some(event.date)
  } else if prior >= ordered && self.net < ordered {
    self.filled_since = None
    self.reopens += 1
  }
  self.trail.push({
    event_id: event.id,
    date: event.date,
    kind: event.kind,
    reference: event.reference,
    approved_due: self.due,
    net_received: self.net,
    outstanding: (ordered - self.net).max(0L),
  })
}

///|
fn ReplayState::reverse(
  self : ReplayState,
  event : LedgerEvent,
  reference : String,
) -> Unit raise InputError {
  match self.posted.get(reference) {
    Some(ReceiptEntry(receipt)) if !receipt.reversed => {
      if receipt.available != receipt.units {
        raise event.invalid(
          "reverse active returns before reversing their receipt",
        )
      }
      receipt.reversed = true
      self.net -= receipt.units
    }
    Some(ReturnEntry(returned)) if !returned.reversed => {
      returned.reversed = true
      returned.receipt.available += returned.units
      self.net += returned.units
    }
    _ =>
      raise event.invalid(
        "reversal must reference an unreversed receipt or return on the same line",
      )
  }
}

///|
fn due_result(net : Int64?, ordered : Int64) -> String {
  match net {
    None => "pending"
    Some(quantity) if quantity >= ordered => "met"
    Some(_) => "missed"
  }
}

///|
fn ReplayState::report(self : ReplayState, as_of : String) -> ReplayLine {
  let ordered = self.line.units.to_int64()
  let original_net = if self.line.due > as_of {
    None
  } else {
    Some(self.original_at_due.unwrap_or(self.net))
  }
  let approved_net = if self.due > as_of {
    None
  } else {
    Some(self.approved_at_due.unwrap_or(self.net))
  }
  {
    id: self.line.id,
    supplier: self.line.supplier,
    original_due: self.line.due,
    approved_due: self.due,
    ordered: self.line.units,
    net_received: self.net,
    outstanding: (ordered - self.net).max(0L),
    excess: (self.net - ordered).max(0L),
    original_due_result: due_result(original_net, ordered),
    approved_due_result: due_result(approved_net, ordered),
    original_due_net: original_net,
    approved_due_net: approved_net,
    currently_filled_since: self.filled_since,
    reopen_count: self.reopens,
    trail: self.trail,
  }
}

///|
/// Replay the ledger prefix through the end of as_of.
pub fn replay(input : ReplayInput) -> ReplayReport raise InputError {
  if !is_date(input.as_of) {
    raise Invalid("invalid replay observation date")
  }
  let states : Map[String, ReplayState] = Map([])
  for line in input.lines {
    if !valid_id(line.id) ||
      !valid_id(line.supplier) ||
      !is_date(line.due) ||
      line.units <= 0 ||
      states.contains(line.id) {
      raise Invalid("invalid or duplicate order line: \{line.id}")
    }
    states[line.id] = {
      line,
      due: line.due,
      net: 0L,
      original_at_due: None,
      approved_at_due: None,
      filled_since: None,
      reopens: 0,
      posted: Map([]),
      trail: [],
    }
  }
  let seen : Set[String] = Set([])
  let mut previous = ""
  for event in input.events {
    if !is_date(event.date) || event.date < previous {
      raise event.invalid(
        "expected a valid posting date in nondecreasing order",
      )
    }
    previous = event.date
    if event.date > input.as_of {
      continue
    }
    if !valid_id(event.id) || seen.contains(event.id) {
      raise event.invalid("invalid or duplicate event id")
    }
    seen.add(event.id)
    guard states.get(event.line_id) is Some(state) else {
      raise event.invalid("unknown order line")
    }
    state.post(event)
  }
  let lines = input.lines.map(line => states[line.id].report(input.as_of))
  { as_of: input.as_of, lines, }
}
