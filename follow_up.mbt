///|
/// Reconcile two observation dates against the same order cohort and ledger.
#derive(ToJson)
pub struct FollowUp {
  due_from : String
  due_to : String
  from_as_of : String
  to_as_of : String
  changes : Array[DeliveryChange]
}

///|
#derive(ToJson)
pub struct DeliveryChange {
  id : String
  supplier : String
  previous_status : DeliveryStatus
  current_status : DeliveryStatus
  outstanding_before : Int32
  outstanding_now : Int32
  excess_before : Int64
  excess_now : Int64
  new_receipt_ids : Array[String]
}

///|
pub extend FollowUp with ToJson::{to_json}

///|
pub extend DeliveryChange with ToJson::{to_json}

///|
/// Report only lines with additional receipts. The order due window stays fixed.
pub fn follow_up(
  input : ReviewInput,
  later_as_of : String,
) -> FollowUp raise InputError {
  let baseline = review(input)
  if !is_date(later_as_of) || later_as_of <= baseline.as_of {
    raise Invalid("follow-up date must be a valid YYYY-MM-DD after as_of")
  }
  let later = review({ ..input, as_of: later_as_of, })
  let changes : Array[DeliveryChange] = []
  // Both reviews contain the same lines, sorted by the same unique line IDs.
  for index, current in later.lines {
    let previous = baseline.lines[index]
    if current.receipt_ids.length() == previous.receipt_ids.length() {
      continue
    }
    let earlier_ids = Set::from_array(previous.receipt_ids)
    changes.push({
      id: current.id,
      supplier: current.supplier,
      previous_status: previous.status,
      current_status: current.status,
      outstanding_before: previous.outstanding,
      outstanding_now: current.outstanding,
      excess_before: previous.excess,
      excess_now: current.excess,
      new_receipt_ids: current.receipt_ids.filter(id => {
        !earlier_ids.contains(id)
      }),
    })
  }
  {
    due_from: baseline.due_from,
    due_to: baseline.due_to,
    from_as_of: baseline.as_of,
    to_as_of: later.as_of,
    changes,
  }
}
