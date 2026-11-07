// The bodies of these tests are the examples in `README.md` and in the doc
// comments of `src/grip.gleam`. `docs_test` keeps them in sync.

import gleam/option
import gleam/uri
import grip
import grip/origin

pub fn readme_usage_test() {
  let assert Ok(policy) =
    "User-Agent: *
    Disallow: /private/"
    |> grip.parse(200)

  let assert Ok(url) = uri.parse("https://example.com/private/report.html")

  assert grip.is_allowed(policy, "LucyBot", url) == False
}

pub fn parse_example_test() {
  assert grip.parse("Disallow: /", 404) == Ok(grip.allow_all())
  assert grip.parse("Disallow: /", 503) == Ok(grip.disallow_all())
  assert grip.parse("", 429) == Error(grip.RateLimited(option.None))
}

pub fn precedence_example_test() {
  let assert Ok(policy) =
    "User-Agent: *
    Disallow: /
    Allow: /public/"
    |> grip.parse(200)

  let assert Ok(public) = uri.parse("/public/report.html")
  let assert Ok(private) = uri.parse("/private/report.html")

  assert grip.is_allowed(policy, "LucyBot", public) == True
  assert grip.is_allowed(policy, "LucyBot", private) == False
}

pub fn product_token_example_test() {
  let assert Ok(policy) =
    "User-Agent: LucyBot
    Disallow: /"
    |> grip.parse(200)

  let assert Ok(url) = uri.parse("/x")

  assert grip.is_allowed(policy, "LucyBot", url) == False
  assert grip.is_allowed(policy, "LucyBot/2.1", url) == False
  assert grip.is_allowed(policy, "GleamBot", url) == True
}

pub fn rate_example_test() {
  let assert Ok(policy) =
    "User-Agent: *
    Crawl-Delay: 2
    Request-Rate: 1/10"
    |> grip.parse(200)

  assert grip.rate(policy, "LucyBot") == Ok(grip.Rate(1, 10.0))
}

pub fn interval_example_test() {
  let rate = grip.Rate(requests: 2, seconds: 10.0)
  assert grip.interval(rate) == 5.0
}

pub fn robots_url_example_test() {
  let assert Ok(url) = uri.parse("https://example.com/private/report.html")
  let assert Ok(site) = origin.from_uri(url)

  assert uri.to_string(origin.robots_url(site))
    == "https://example.com/robots.txt"
}
