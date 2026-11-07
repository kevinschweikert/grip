import gleam/uri.{Uri, empty}
import grip

pub fn token_matches_inside_a_full_header_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /"
    |> grip.parse(200)
  assert !grip.is_allowed(
    policy,
    "Mozilla/5.0 (compatible; FooBot/1.0; +https://example.com/bot)",
    Uri(..empty, path: "/x"),
  )
}

pub fn token_matches_a_bare_product_token_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
  assert !grip.is_allowed(policy, "FooBot/2.1", Uri(..empty, path: "/x"))
}

pub fn matching_is_case_insensitive_test() {
  let assert Ok(policy) =
    "User-agent: FOOBOT
    Disallow: /"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "foobot", Uri(..empty, path: "/x"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
  assert !grip.is_allowed(policy, "fOoBoT/1.0", Uri(..empty, path: "/x"))
}

pub fn a_shorter_token_matches_a_longer_agent_test() {
  let assert Ok(policy) =
    "User-agent: bot
    Allow: /

    User-agent: *
    Disallow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
}

pub fn a_longer_token_does_not_match_a_shorter_agent_test() {
  let assert Ok(policy) =
    "User-agent: FooBot-News
    Disallow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
}

pub fn the_longest_matching_token_wins_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /

    User-agent: FooBot-News
    Allow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot-News", Uri(..empty, path: "/x"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
}

pub fn the_longest_matching_token_wins_regardless_of_order_test() {
  let assert Ok(policy) =
    "User-agent: FooBot-News
    Allow: /

    User-agent: FooBot
    Disallow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot-News", Uri(..empty, path: "/x"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
}

pub fn any_specific_match_beats_the_wildcard_test() {
  let assert Ok(policy) =
    "User-agent: *
    Disallow: /

    User-agent: bot
    Allow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
}

pub fn an_unmatched_agent_falls_back_to_the_wildcard_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Allow: /

    User-agent: *
    Disallow: /"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/x"))
}

pub fn an_empty_token_matches_nothing_test() {
  let assert Ok(policy) =
    "User-agent:
    Disallow: /

    User-agent: FooBot
    Allow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/x"))
  assert grip.is_allowed(policy, "", Uri(..empty, path: "/x"))
}

pub fn extensions_use_the_same_matching_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-Delay: 5"
    |> grip.parse(200)
  assert grip.crawl_delay(policy, "Mozilla/5.0 (compatible; FooBot/1.0)")
    == Ok(grip.Rate(1, 5.0))
}
