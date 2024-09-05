import antigone.{hash, hasher}
import birl.{
  type Day, type Month, type Time, type Weekday, add, now, set_day,
  set_time_of_day,
}
import birl/duration.{type Duration, days}
import gleam/bit_array.{base64_decode, base64_encode, from_string}
import gleam/io
import gleam/iterator.{type Iterator, type Step, Done, Next}
import gleam/result.{try}
import ids/uuid.{generate_v4}

pub fn main() {
  io.println("Hello?")
  let c1 =
    Chore(
      id: 1,
      name: "Test",
      description: "This is a test",
      frequency: FixedDayOfWeek(birl.Tue, 2),
      due: now(),
    )
  io.println("Hello1?")
  let c2 = Chore(..c1, frequency: Once)
  io.println("Hello2?")
  let c3 = Chore(..c2, frequency: FixedDayOfWeek(birl.Thu, 1))
  io.println("Hello3?")

  debug_chore(c1)
  debug_chore(c2)
  debug_chore(c3)
  Ok("")
}

pub fn chores(c: Chore, history: List(ChoreEvent)) -> Iterator(birl.Time) {
  iterator.unfold(ChoreAccumulator(chore: c, history: history), next_chore)
}

fn debug_chore(c: Chore) {
  c
  |> chores([])
  |> iterator.take(5)
  |> iterator.map(fn(t) {
    t |> birl.weekday |> birl.weekday_to_string
    <> ", "
    <> birl.to_naive_date_string(t)
  })
  |> iterator.to_list
  |> io.debug
}

pub fn new_user(
  name: String,
  email: String,
  password: String,
) -> Result(User, String) {
  use id <- try(generate_v4())
  let p_hash =
    password
    |> fn(p) { p <> id }
    |> from_string
    |> hash(hasher(), _)
  Ok(User(id: id, email: email, password_hash: p_hash))
}

fn day_to_time(d: Day) -> birl.Time {
  now()
  |> set_day(d)
  |> set_time_of_day(birl.TimeOfDay(
    hour: 0,
    minute: 0,
    second: 0,
    milli_second: 0,
  ))
}

pub type User {
  User(id: String, email: String, password_hash: String)
}

pub type Chore {
  Chore(
    id: Int,
    name: String,
    description: String,
    frequency: ChoreFrequency,
    due: Time,
  )
}

fn debug_date_weekday(t: Time) -> Time {
  t
  |> birl.to_naive
  |> fn(s) { s <> ", a " <> t |> birl.weekday |> birl.weekday_to_string }
  |> io.debug
  t
}

pub fn following_weekday(t: Time, w: Weekday) -> Time {
  let sample = birl.add(t, days(1))
  case birl.weekday(sample) == w {
    True -> sample
    _ -> following_weekday(sample, w)
  }
}

pub type ChoreAccumulator {
  ChoreAccumulator(chore: Chore, history: List(ChoreEvent))
}

pub fn next_chore(ca: ChoreAccumulator) -> Step(birl.Time, ChoreAccumulator) {
  case ca.chore.frequency {
    Never -> Done
    Once -> next_chore_once(ca)
    FixedDayOfWeek(weekday, interval) ->
      next_chore_fixed_day_of_week(weekday, interval, ca.chore)
    FixedMonthly(interval, date) -> Done
    FixedDaily(interval) -> next_chore_fixed_daily(ca, interval)
    _ -> Done
  }
}

fn next_chore_fixed_daily(
  ca: ChoreAccumulator,
  interval: Int,
) -> Step(birl.Time, ChoreAccumulator) {
  Next(
    ca.chore.due,
    ChoreAccumulator(
      ..ca,
      chore: Chore(
        ..ca.chore,
        due: birl.add(ca.chore.due, duration.days(interval)),
      ),
    ),
  )
}

fn next_chore_once(ca: ChoreAccumulator) -> Step(birl.Time, ChoreAccumulator) {
  Next(
    ca.chore.due,
    ChoreAccumulator(..ca, chore: Chore(..ca.chore, frequency: Never)),
  )
}

fn next_chore_fixed_day_of_week(
  weekday: Weekday,
  interval: Int,
  c: Chore,
) -> Step(birl.Time, ChoreAccumulator) {
  Next(
    c.due,
    ChoreAccumulator(
      chore: Chore(
        ..c,
        due: c.due
          |> birl.add(duration.weeks(interval - 1))
          |> following_weekday(weekday),
      ),
      history: [],
    ),
  )
}

pub type ChoreEvent {
  Complete(Time, Chore)
  Snooze(Time, Duration, Chore)
  Skip(Time, Chore)
  Miss(Time, Chore)
}

/// Fixed_ frequencies calculate their next due dates based on the original date and do not stay due after their due date has passed
/// Other frequencies will calculate their next date based on the most recent completion dates, and will remain due until done
/// Ints represent the interval, so FixedDayOfWeek(Tuesday, 2) will be due every second Tuesday
pub type ChoreFrequency {
  Once
  Never
  FixedDayOfWeek(weekday: Weekday, interval: Int)
  FixedMonthly(interval: Int, date: Int)
  Monthly(interval: Int)
  FixedWeekly(interval: Int)
  Weekly(interval: Int)
  Daily(interval: Int)
  FixedDaily(interval: Int)
}
