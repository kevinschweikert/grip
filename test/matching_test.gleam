import gleam/option
import gleam/uri.{Uri, empty}
import grip

pub fn head_segment_is_anchored_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /foo"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/bar/foo"))
}

pub fn end_anchor_does_not_free_the_start_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /foo$"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foobar"))
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/x/foo"))
}

pub fn end_anchor_applies_to_the_query_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /*.php$"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/index.php"))
  assert grip.is_allowed(
    policy,
    "FooBot",
    Uri(..empty, path: "/index.php", query: option.Some("q=1")),
  )
}

pub fn end_anchor_takes_rightmost_occurrence_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /*.php$"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/a.php.php"))
}

pub fn end_anchor_cannot_overlap_the_head_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /ab*b$"
    |> grip.parse(200)
  assert grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/ab"))
}

pub fn trailing_wildcard_cancels_the_anchor_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /foo*$"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foobar"))
}

pub fn trailing_wildcard_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /foo/*"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/"))
}

pub fn leading_wildcard_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: *.php"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/foo/bar.php"))
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/a.php"))
}

pub fn consecutive_wildcards_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /a**b"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/axxb"))
}

pub fn leftmost_occurrence_leaves_room_for_later_segments_test() {
  let assert Ok(policy) =
    "User-agent: FooBot
    Disallow: /x*ab*abc"
    |> grip.parse(200)
  assert !grip.is_allowed(policy, "FooBot", Uri(..empty, path: "/xababc"))
}
