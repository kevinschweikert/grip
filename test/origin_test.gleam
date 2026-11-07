import gleam/http/request
import gleam/uri
import grip/origin

pub fn from_uri_ignores_the_path_test() {
  let assert Ok(report) = uri.parse("https://example.com/private/report.html")
  let assert Ok(index) = uri.parse("https://example.com/public/")

  let assert Ok(from_report) = origin.from_uri(report)
  let assert Ok(from_index) = origin.from_uri(index)

  assert from_report == from_index
}

pub fn from_uri_distinguishes_hosts_test() {
  let assert Ok(example) = uri.parse("https://example.com/")
  let assert Ok(other) = uri.parse("https://example.org/")

  let assert Ok(from_example) = origin.from_uri(example)
  let assert Ok(from_other) = origin.from_uri(other)

  assert from_example != from_other
}

pub fn from_uri_distinguishes_schemes_test() {
  let assert Ok(secure) = uri.parse("https://example.com/")
  let assert Ok(plain) = uri.parse("http://example.com/")

  let assert Ok(from_secure) = origin.from_uri(secure)
  let assert Ok(from_plain) = origin.from_uri(plain)

  assert from_secure != from_plain
}

pub fn from_uri_distinguishes_ports_test() {
  let assert Ok(default) = uri.parse("https://example.com/")
  let assert Ok(custom) = uri.parse("https://example.com:8443/")

  let assert Ok(from_default) = origin.from_uri(default)
  let assert Ok(from_custom) = origin.from_uri(custom)

  assert from_default != from_custom
}

pub fn from_uri_lowercases_the_host_test() {
  let assert Ok(shouted) = uri.parse("https://EXAMPLE.CoM/")
  let assert Ok(quiet) = uri.parse("https://example.com/")

  let assert Ok(from_shouted) = origin.from_uri(shouted)
  let assert Ok(from_quiet) = origin.from_uri(quiet)

  assert from_shouted == from_quiet
}

pub fn from_uri_infers_port_443_for_https_test() {
  let assert Ok(implicit) = uri.parse("https://example.com/")
  let assert Ok(explicit) = uri.parse("https://example.com:443/")

  let assert Ok(from_implicit) = origin.from_uri(implicit)
  let assert Ok(from_explicit) = origin.from_uri(explicit)

  assert from_implicit == from_explicit
}

pub fn from_uri_infers_port_80_for_http_test() {
  let assert Ok(implicit) = uri.parse("http://example.com/")
  let assert Ok(explicit) = uri.parse("http://example.com:80/")

  let assert Ok(from_implicit) = origin.from_uri(implicit)
  let assert Ok(from_explicit) = origin.from_uri(explicit)

  assert from_implicit == from_explicit
}

pub fn from_uri_rejects_a_relative_uri_test() {
  let assert Ok(relative) = uri.parse("/private/report.html")

  assert origin.from_uri(relative) == Error(Nil)
}

pub fn from_uri_rejects_an_empty_host_test() {
  let assert Ok(hostless) = uri.parse("https:///private/report.html")

  assert origin.from_uri(hostless) == Error(Nil)
}

pub fn from_uri_rejects_a_non_http_scheme_test() {
  let assert Ok(mail) = uri.parse("mailto:lucy@example.com")

  assert origin.from_uri(mail) == Error(Nil)
}

pub fn from_request_matches_the_uri_it_was_built_from_test() {
  let url = "https://example.com/private/report.html"

  let assert Ok(parsed) = uri.parse(url)
  let assert Ok(expected) = origin.from_uri(parsed)
  let assert Ok(request) = request.to(url)

  assert origin.from_request(request) == expected
}

pub fn robots_url_points_at_the_origin_root_test() {
  let assert Ok(url) = uri.parse("https://example.com/private/report.html")
  let assert Ok(site) = origin.from_uri(url)

  assert uri.to_string(origin.robots_url(site))
    == "https://example.com/robots.txt"
}

pub fn robots_url_keeps_a_non_default_port_test() {
  let assert Ok(url) = uri.parse("https://example.com:8443/private/")
  let assert Ok(site) = origin.from_uri(url)

  assert uri.to_string(origin.robots_url(site))
    == "https://example.com:8443/robots.txt"
}

pub fn robots_url_round_trips_through_from_uri_test() {
  let assert Ok(url) = uri.parse("http://example.com:8080/private/")
  let assert Ok(site) = origin.from_uri(url)

  assert origin.from_uri(origin.robots_url(site)) == Ok(site)
}

pub fn covers_a_url_on_the_same_origin_test() {
  let assert Ok(url) = uri.parse("https://example.com/")
  let assert Ok(site) = origin.from_uri(url)
  let assert Ok(link) = uri.parse("https://example.com/public/report.html")

  assert origin.covers(site, link)
}

pub fn covers_ignores_the_host_case_test() {
  let assert Ok(url) = uri.parse("https://example.com/")
  let assert Ok(site) = origin.from_uri(url)
  let assert Ok(link) = uri.parse("https://EXAMPLE.CoM/public/")

  assert origin.covers(site, link)
}

pub fn covers_rejects_another_host_test() {
  let assert Ok(url) = uri.parse("https://example.com/")
  let assert Ok(site) = origin.from_uri(url)
  let assert Ok(link) = uri.parse("https://example.org/public/")

  assert !origin.covers(site, link)
}

pub fn covers_rejects_another_scheme_test() {
  let assert Ok(url) = uri.parse("https://example.com/")
  let assert Ok(site) = origin.from_uri(url)
  let assert Ok(link) = uri.parse("http://example.com/public/")

  assert !origin.covers(site, link)
}

pub fn covers_rejects_a_relative_uri_test() {
  let assert Ok(url) = uri.parse("https://example.com/")
  let assert Ok(site) = origin.from_uri(url)
  let assert Ok(link) = uri.parse("/public/report.html")

  assert !origin.covers(site, link)
}
