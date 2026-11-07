import grip.{Rate}

pub fn rate_uses_crawl_delay_when_alone_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: 2.5
    Disallow: /x"
    |> grip.parse(200)
  assert grip.rate(policy, "foobot") == Ok(Rate(1, 2.5))
}

pub fn rate_uses_request_rate_when_alone_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Request-rate: 1/5
    Disallow: /x"
    |> grip.parse(200)
  assert grip.rate(policy, "foobot") == Ok(Rate(1, 5.0))
}

pub fn rate_prefers_the_slower_crawl_delay_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: 10
    Request-rate: 1/5
    Disallow: /x"
    |> grip.parse(200)
  assert grip.rate(policy, "foobot") == Ok(Rate(1, 10.0))
}

pub fn rate_prefers_the_slower_request_rate_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: 2
    Request-rate: 1/5
    Disallow: /x"
    |> grip.parse(200)
  assert grip.rate(policy, "foobot") == Ok(Rate(1, 5.0))
}

pub fn rate_is_independent_of_directive_order_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Request-rate: 1/5
    Crawl-delay: 10
    Disallow: /x"
    |> grip.parse(200)
  assert grip.rate(policy, "foobot") == Ok(Rate(1, 10.0))
}

pub fn rate_keeps_the_burst_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Request-rate: 2/10
    Disallow: /x"
    |> grip.parse(200)
  assert grip.rate(policy, "foobot") == Ok(Rate(2, 10.0))
}

pub fn rate_absent_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /x"
    |> grip.parse(200)
  assert grip.rate(policy, "foobot") == Error(Nil)
}

pub fn rate_falls_back_to_wildcard_test() {
  let assert Ok(policy) =
    "User-agent: *
    Crawl-delay: 1.5
    Disallow: /a
    User-agent: FooBot
    Disallow: /x"
    |> grip.parse(200)
  assert grip.rate(policy, "barbot") == Ok(Rate(1, 1.5))
  assert grip.rate(policy, "foobot") == Error(Nil)
}

pub fn rate_unavailable_status_test() {
  let assert Ok(policy) = "" |> grip.parse(404)
  assert grip.rate(policy, "foobot") == Error(Nil)
}

pub fn interval_of_a_single_request_rate_test() {
  assert grip.interval(Rate(1, 2.5)) == 2.5
}

pub fn interval_divides_a_burst_test() {
  assert grip.interval(Rate(2, 10.0)) == 5.0
}

pub fn interval_is_equal_for_equivalent_rates_test() {
  assert grip.interval(Rate(1, 5.0)) == grip.interval(Rate(2, 10.0))
}
