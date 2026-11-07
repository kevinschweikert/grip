import gleam/dict
import gleam/uri.{Uri, empty}
import grip

pub fn no_extension_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /x"
    |> grip.parse(200)
  let assert Ok(extensions) = grip.extensions(policy, "foobot")
  assert dict.is_empty(extensions)
}

pub fn extension_gets_collected_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /x,
    Bar: baz"
    |> grip.parse(200)
  let assert Ok(extensions) = grip.extensions(policy, "foobot")
  assert dict.get(extensions, "bar") == Ok("baz")
}

pub fn multiple_extension_get_collected_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /x,
    my-extension: my_value
    my-other-extension: my other value"
    |> grip.parse(200)
  let assert Ok(extensions) = grip.extensions(policy, "foobot")
  assert dict.get(extensions, "my-extension") == Ok("my_value")
  assert dict.get(extensions, "my-other-extension") == Ok("my other value")
}

pub fn known_extensions_stay_in_the_raw_dict_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Crawl-delay: 2.5
    Request-rate: 1/5
    Disallow: /x"
    |> grip.parse(200)
  let assert Ok(extensions) = grip.extensions(policy, "foobot")
  assert dict.get(extensions, "crawl-delay") == Ok("2.5")
  assert dict.get(extensions, "request-rate") == Ok("1/5")
}

pub fn extension_before_any_user_agent_is_ignored_test() {
  let assert Ok(policy) =
    "Bar: baz
    User-agent: FooBot
    Disallow: /x"
    |> grip.parse(200)
  let assert Ok(extensions) = grip.extensions(policy, "foobot")
  assert dict.is_empty(extensions)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
}

pub fn extension_after_a_rule_does_not_merge_the_next_group_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /x
    Bar: baz
    User-agent: BarBot
    Disallow: /y"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/y"))
  assert grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/x"))
  assert !grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/y"))

  let assert Ok(foobot) = grip.extensions(policy, "FooBot")
  let assert Ok(barbot) = grip.extensions(policy, "BarBot")
  assert dict.get(foobot, "bar") == Ok("baz")
  assert dict.is_empty(barbot)
}
