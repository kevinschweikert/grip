import gleam/uri.{Uri, empty}
import grip.{Rate}

pub fn crawl_delay_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: 2.5
    Disallow: /x"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "foobot") == Ok(Rate(1, 2.5))
}

pub fn crawl_delay_integer_value_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: 10"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "foobot") == Ok(Rate(1, 10.0))
}

pub fn crawl_delay_agent_is_canonicalized_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: 2.5"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "foobot") == Ok(Rate(1, 2.5))
  assert grip.crawl_delay(policy, "FooBot") == Ok(Rate(1, 2.5))
  assert grip.crawl_delay(policy, "FooBot/2.1") == Ok(Rate(1, 2.5))
}

pub fn crawl_delay_absent_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /x"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "foobot") == Error(Nil)
}

pub fn crawl_delay_falls_back_to_wildcard_test() {
  let assert Ok(policy) =
    "User-agent: *
    Crawl-delay: 1.5
    User-agent: FooBot
    Disallow: /x"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "barbot") == Ok(Rate(1, 1.5))
}

pub fn crawl_delay_does_not_fall_back_when_group_matches_test() {
  let assert Ok(policy) =
    "User-agent: *
    Crawl-delay: 1.5
    Disallow: /
    User-agent: FooBot
    Disallow: /x"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "foobot") == Error(Nil)
}

pub fn crawl_delay_unknown_agent_without_wildcard_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: 2.5"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "barbot") == Error(Nil)
}

pub fn crawl_delay_survives_group_merge_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: 2.5
    User-agent: BarBot
    Disallow: /
    User-agent: FooBot
    Disallow: /x"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "foobot") == Ok(Rate(1, 2.5))
}

pub fn crawl_delay_last_value_wins_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: 1.0
    Crawl-delay: 2.0"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "foobot") == Ok(Rate(1, 2.0))
}

pub fn crawl_delay_malformed_value_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: soon"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "foobot") == Error(Nil)
}

pub fn crawl_delay_unavailable_status_test() {
  let assert Ok(policy) = "" |> grip.parse(404)
  assert grip.crawl_delay(policy, "foobot") == Error(Nil)
}

/// Crawl-delay is outside RFC 9309's grammar, so it is an unrecognized line
/// that must be ignored — which includes not splitting the group it sits in.
pub fn crawl_delay_does_not_end_a_group_test() {
  let assert Ok(policy) =
    "User-agent: *
    Crawl-delay: 1.5
    User-agent: FooBot
    Disallow: /"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "foobot") == Ok(Rate(1, 1.5))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/"))
  assert !grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/"))
}
