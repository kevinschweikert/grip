import grip.{Rate}

pub fn request_rate_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Request-rate: 1/5
    Disallow: /x"
    |> grip.parse(200)
  assert grip.request_rate(policy, "foobot") == Ok(Rate(1, 5.0))
}

pub fn request_rate_agent_is_canonicalized_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Request-rate: 1/5"
    |> grip.parse(200)
  assert grip.request_rate(policy, "FooBot/2.1") == Ok(Rate(1, 5.0))
}

pub fn request_rate_absent_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /x"
    |> grip.parse(200)
  assert grip.request_rate(policy, "foobot") == Error(Nil)
}

pub fn request_rate_falls_back_to_wildcard_test() {
  let assert Ok(policy) =
    "User-agent: *
    Request-rate: 1/5
    User-agent: FooBot
    Disallow: /x"
    |> grip.parse(200)
  assert grip.request_rate(policy, "barbot") == Ok(Rate(1, 5.0))
}

pub fn request_rate_malformed_value_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Request-rate: soon"
    |> grip.parse(200)
  assert grip.request_rate(policy, "foobot") == Error(Nil)
}
