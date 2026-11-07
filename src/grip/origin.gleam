//// The scheme, host and port that a `robots.txt` applies to.
////
//// RFC 9309 scopes a `robots.txt` to one scheme, host and port, so
//// `https://example.com` and `http://example.com` are served by different
//// files and bound by different rules. An `Origin` is that scope: the key to
//// cache a policy under, the URL to fetch the rules from, and the test for
//// whether a link found on a page is covered by them.

import gleam/http
import gleam/http/request
import gleam/option
import gleam/result
import gleam/string
import gleam/uri

/// A type representing the robots origin.
///
/// Primarily intended to be used as a lookup key by crawlers
pub opaque type Origin {
  Origin(scheme: http.Scheme, host: String, port: Int)
}

/// Creates an origin from a URL
pub fn from_uri(uri: uri.Uri) -> Result(Origin, Nil) {
  case uri {
    uri.Uri(scheme: option.Some(scheme), host: option.Some(host), port:, ..)
      if host != ""
    -> {
      use scheme <- result.map(http.scheme_from_string(scheme))
      Origin(
        scheme:,
        host: string.lowercase(host),
        port: port
          |> option.lazy_unwrap(fn() { port_from_scheme(scheme) }),
      )
    }
    _ -> Error(Nil)
  }
}

/// Creates an origin from an HTTP request
pub fn from_request(request: request.Request(a)) -> Origin {
  Origin(
    scheme: request.scheme,
    host: string.lowercase(request.host),
    port: request.port
      |> option.lazy_unwrap(fn() { port_from_scheme(request.scheme) }),
  )
}

fn port_from_scheme(scheme: http.Scheme) -> Int {
  case scheme {
    http.Http -> 80
    http.Https -> 443
  }
}

/// The URL to fetch the rules from
///
/// The scheme's default port is left out, so the URL comes back in its
/// canonical form. Any other port is kept.
///
/// ## Examples
///
/// ```gleam robots_url
/// let assert Ok(url) = uri.parse("https://example.com/private/report.html")
/// let assert Ok(site) = origin.from_uri(url)
/// 
/// assert uri.to_string(origin.robots_url(site))
///   == "https://example.com/robots.txt"
/// ```
pub fn robots_url(origin: Origin) -> uri.Uri {
  uri.Uri(
    ..uri.empty,
    scheme: origin.scheme
      |> http.scheme_to_string
      |> option.Some,
    host: option.Some(origin.host),
    port: case origin.port == port_from_scheme(origin.scheme) {
      True -> option.None
      False -> option.Some(origin.port)
    },
    path: "/robots.txt",
  )
}

/// Whether a URL belongs to this origin
///
/// Useful to check links found on a page if they belong to the same crawl
/// target
pub fn covers(origin: Origin, uri: uri.Uri) -> Bool {
  Ok(origin) == from_uri(uri)
}
