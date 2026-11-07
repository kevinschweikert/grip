// Ported from the test cases of google/policytxt's policy_test.cc,
// the reference implementation for RFC 9309.
// Copyright 2019 Google LLC, Apache License 2.0.

import gleam/http/response
import gleam/option
import gleam/string
import gleam/time/timestamp
import gleam/uri.{Uri, empty}
import gleeunit
import grip

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn line_syntax_line_correct_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    disallow: /"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/y"))
}

pub fn line_syntax_line_incorrect_test() {
  let assert Ok(policy) =
    "foo: FooBot
    bar: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/y"))
}

// NOTE: this test is here only because the Google test suite has this test.
// currently `grip` does not parse a directive with a missing colon.
// 
// pub fn line_syntax_line_missing_colon_test() {
//   let assert Ok(policy) =
//     "user-agent FooBot
//     disallow /"
//     |> grip.parse(200)
//   assert !grip.allow(policy, "FooBot", Uri(..empty, path: "/x/y"))
// }

pub fn line_syntax_groups_test() {
  let assert Ok(policy) =
    "allow: /foo/bar/

    user-agent: FooBot
    disallow: /
    allow: /x/
    user-agent: BarBot
    disallow: /
    allow: /y/


    allow: /w/
    user-agent: BazBot

    user-agent: FooBot
    allow: /z/
    disallow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/b"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/z/d"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/y/c"))
  assert grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/y/c"))
  assert grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/w/a"))
  assert !grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/z/d"))
  assert grip.is_allowed(policy, "BazBot", Uri(..empty, path: "/z/d"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar/"))
  assert !grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/foo/bar/"))
  assert !grip.is_allowed(policy, "BazBot", Uri(..empty, path: "/foo/bar/"))
}

pub fn line_syntax_groups_other_rules_sitemap_test() {
  let assert Ok(policy) =
    "User-agent: BarBot
    Sitemap: https://foo.bar/sitemap
    User-agent: *
    Disallow: /"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/"))
  assert !grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/"))
}

pub fn line_syntax_groups_other_rules_unknown_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Invalid-Unknown-Line: unknown
    User-agent: *
    Disallow: /"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/"))
  assert !grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/"))
}

pub fn rep_line_names_case_insensitive_upper_test() {
  let assert Ok(policy) =
    "USER-AGENT: FooBot
    ALLOW: /x/
    DISALLOW: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/y"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/a/b"))
}

pub fn rep_line_names_case_insensitive_lower_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    allow: /x/
    disallow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/y"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/a/b"))
}

pub fn rep_line_names_case_insensitive_camel_test() {
  let assert Ok(policy) =
    "uSeR-aGeNt: FooBot
    AlLoW: /x/
    dIsAlLoW: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/y"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/a/b"))
}

pub fn user_agent_value_case_insensitive_upper_test() {
  let assert Ok(policy) =
    "User-Agent: FOO BAR
    Allow: /x/
    Disallow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "Foo", Uri(..empty, path: "/x/y"))
  assert !grip.is_allowed(policy, "Foo", Uri(..empty, path: "/a/b"))
  assert grip.is_allowed(policy, "foo", Uri(..empty, path: "/x/y"))
  assert !grip.is_allowed(policy, "foo", Uri(..empty, path: "/a/b"))
}

pub fn user_agent_value_case_insensitive_lower_test() {
  let assert Ok(policy) =
    "User-Agent: foo bar
    Allow: /x/
    Disallow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "Foo", Uri(..empty, path: "/x/y"))
  assert !grip.is_allowed(policy, "Foo", Uri(..empty, path: "/a/b"))
  assert grip.is_allowed(policy, "foo", Uri(..empty, path: "/x/y"))
  assert !grip.is_allowed(policy, "foo", Uri(..empty, path: "/a/b"))
}

pub fn user_agent_value_case_insensitive_camel_test() {
  let assert Ok(policy) =
    "User-Agent: FoO bAr
    Allow: /x/
    Disallow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "Foo", Uri(..empty, path: "/x/y"))
  assert !grip.is_allowed(policy, "Foo", Uri(..empty, path: "/a/b"))
  assert grip.is_allowed(policy, "foo", Uri(..empty, path: "/x/y"))
  assert !grip.is_allowed(policy, "foo", Uri(..empty, path: "/a/b"))
}

pub fn global_groups_secondary_empty_test() {
  let assert Ok(policy) = "" |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/y"))
}

pub fn global_groups_secondary_global_test() {
  let assert Ok(policy) =
    "user-agent: *
    allow: /
    user-agent: FooBot
    disallow: /"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/y"))
  assert grip.is_allowed(policy, "BarBot", Uri(..empty, path: "/x/y"))
}

pub fn global_groups_secondary_only_specific_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    allow: /
    user-agent: BarBot
    disallow: /
    user-agent: BazBot
    disallow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "QuxBot", Uri(..empty, path: "/x/y"))
}

pub fn allow_disallow_value_case_sensitive_test() {
  let assert Ok(lowercase) =
    "user-agent: FooBot
    disallow: /x/"
    |> grip.parse(200)
  let assert Ok(uppercase) =
    "user-agent: FooBot
    disallow: /X/"
    |> grip.parse(200)
  assert !grip.is_allowed(lowercase, "FooBot", Uri(..empty, path: "/x/y"))
  assert grip.is_allowed(uppercase, "FooBot", Uri(..empty, path: "/x/y"))
}

pub fn longest_match_disallow_longer_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    disallow: /x/page.html
    allow: /x/"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/page.html"))
}

pub fn longest_match_allow_longer_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    allow: /x/page.html
    disallow: /x/"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/page.html"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/"))
}

pub fn longest_match_empty_values_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    disallow:
    allow:"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/page.html"))
}

pub fn longest_match_root_tie_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    disallow: /
    allow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/page.html"))
}

pub fn longest_match_trailing_slash_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    disallow: /x
    allow: /x/"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/"))
}

pub fn longest_match_identical_patterns_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    disallow: /x/page.html
    allow: /x/page.html"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/page.html"))
}

pub fn longest_match_wildcard_longer_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    allow: /page
    disallow: /*.html"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/page.html"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/page"))
}

pub fn longest_match_wildcard_shorter_test() {
  let assert Ok(policy) =
    "user-agent: FooBot
    allow: /x/page.
    disallow: /*.html"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/page.html"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/y.html"))
}

pub fn longest_match_most_specific_group_test() {
  let assert Ok(policy) =
    "User-agent: *
    Disallow: /x/
    User-agent: FooBot
    Disallow: /y/"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/page"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/y/page"))
}

pub fn encoding_unencoded_query_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /
    Allow: /foo/bar?qux=taz&baz=http://foo.bar?tar&par"
    |> grip.parse(200)
  assert grip.is_allowed(
    policy,
    "FooBot",
    Uri(
      ..empty,
      path: "/foo/bar",
      query: option.Some("qux=taz&baz=http://foo.bar?tar&par"),
    ),
  )
}

pub fn encoding_utf8_pattern_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /
    Allow: /foo/bar/ツ"
    |> grip.parse(200)
  assert grip.is_allowed(
    policy,
    "FooBot",
    Uri(..empty, path: "/foo/bar/%E3%83%84"),
  )
  // Deviates from upstream: we encode the URL as well as the pattern, so both
  // spellings match. Google encodes only the pattern, leaving the URL to the
  // caller, and so expects this one to be disallowed.
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar/ツ"))
}

pub fn encoding_percent_encoded_pattern_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /
    Allow: /foo/bar/%E3%83%84"
    |> grip.parse(200)
  assert grip.is_allowed(
    policy,
    "FooBot",
    Uri(..empty, path: "/foo/bar/%E3%83%84"),
  )
  // Deviates from upstream, as above.
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar/ツ"))
}

pub fn encoding_percent_encoded_ascii_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /
    Allow: /foo/bar/%62%61%7A"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar/baz"))
  assert grip.is_allowed(
    policy,
    "FooBot",
    Uri(..empty, path: "/foo/bar/%62%61%7A"),
  )
}

pub fn special_characters_wildcard_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /foo/bar/quz
    Allow: /foo/*/qux"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar/quz"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/quz"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo//quz"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bax/quz"))
}

pub fn special_characters_anchor_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /foo/bar$
    Allow: /foo/bar/qux"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar/qux"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar/"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar/baz"))
}

pub fn special_characters_comment_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    # Disallow: /
    Disallow: /foo/quz#qux
    Allow: /"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/quz"))
}

pub fn response_status_code_test() {
  let assert Ok(four_hundred) = grip.parse("", 400)
  let assert Ok(five_hundred) = grip.parse("", 500)

  assert grip.is_allowed(four_hundred, "FooBot", Uri(..empty, path: "/foo"))
  assert !grip.is_allowed(five_hundred, "FooBot", Uri(..empty, path: "/foo"))
}

pub fn parse_rate_limit_test() {
  assert Error(grip.RateLimited(option.None)) == grip.parse("", 429)
}

pub fn from_response_rate_limit_without_header_test() {
  assert Error(grip.RateLimited(option.None))
    == response.new(429) |> grip.from_response
}

pub fn from_response_rate_limit_with_delay_header_test() {
  assert Error(grip.RateLimited(option.Some(grip.Delay(10))))
    == response.new(429)
    |> response.set_header("retry-after", "10")
    |> grip.from_response
}

pub fn from_response_rate_limit_with_zero_delay_header_test() {
  assert Error(grip.RateLimited(option.Some(grip.Delay(0))))
    == response.new(429)
    |> response.set_header("retry-after", "0")
    |> grip.from_response
}

pub fn from_response_rate_limit_with_padded_delay_header_test() {
  assert Error(grip.RateLimited(option.Some(grip.Delay(10))))
    == response.new(429)
    |> response.set_header("retry-after", "  10  ")
    |> grip.from_response
}

pub fn from_response_rate_limit_with_negative_header_test() {
  assert Error(grip.RateLimited(option.None))
    == response.new(429)
    |> response.set_header("retry-after", "-10")
    |> grip.from_response
}

pub fn from_response_rate_limit_with_unparsable_header_test() {
  assert Error(grip.RateLimited(option.None))
    == response.new(429)
    |> response.set_header("retry-after", "later")
    |> grip.from_response
}

pub fn from_response_rate_limit_with_http_date_header_test() {
  let assert Ok(expected) = timestamp.parse_rfc3339("2015-10-21T07:28:00Z")
  assert Error(grip.RateLimited(option.Some(grip.At(expected))))
    == response.new(429)
    |> response.set_header("retry-after", "Wed, 21 Oct 2015 07:28:00 GMT")
    |> grip.from_response
}

pub fn from_response_rate_limit_with_padded_http_date_header_test() {
  let assert Ok(expected) = timestamp.parse_rfc3339("2015-10-21T07:28:00Z")
  assert Error(grip.RateLimited(option.Some(grip.At(expected))))
    == response.new(429)
    |> response.set_header("retry-after", " Wed, 21 Oct 2015 07:28:00 GMT ")
    |> grip.from_response
}

pub fn ignore_utf8_bom_test() {
  let assert Ok(policy) =
    "\u{FEFF}User-agent: FooBot\nDisallow: /"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/y"))
}

pub fn parse_limit_keeps_rules_before_the_limit_test() {
  let robots =
    "User-agent: FooBot\nDisallow: /x\n#"
    <> string.repeat("a", 512_000)
    <> "\nDisallow: /y"
  let assert Ok(policy) = grip.parse(robots, 200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/y"))
}

pub fn parse_limit_counts_bytes_not_graphemes_test() {
  // "€" is three bytes in UTF-8, so the comment is 600_000 bytes of 200_000
  // graphemes and everything after it falls past the limit.
  let robots =
    "User-agent: FooBot\nDisallow: /x\n#"
    <> string.repeat("€", 200_000)
    <> "\nDisallow: /y"
  let assert Ok(policy) = grip.parse(robots, 200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/y"))
}

pub fn parse_limit_accepts_empty_body_test() {
  let assert Ok(policy) = grip.parse("", 200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
}

pub fn parse_limit_ignored_for_unavailable_status_test() {
  let robots =
    "User-agent: FooBot\nDisallow: /x\n#" <> string.repeat("a", 512_000)
  let assert Ok(policy) = grip.parse(robots, 404)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
}

pub fn parse_limit_ignored_for_unreachable_status_test() {
  let robots = "User-agent: FooBot\nAllow: /x\n#" <> string.repeat("a", 512_000)
  let assert Ok(policy) = grip.parse(robots, 503)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x"))
}
