//// An RFC 9309 `robots.txt` parser and matcher.
////
//// Turn what a server returned into a `Policy` with `parse` or
//// `from_response`, then ask it whether a URL is allowed, how long to wait
//// between requests, and where the sitemaps are.
////
//// A `Policy` describes the rules of a single origin. Use `grip/origin` to
//// find the URL to fetch those rules from, and to key the cache you keep them
//// in.

import gleam/bool
import gleam/dict
import gleam/float
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/pair
import gleam/result
import gleam/string
import gleam/time/timestamp
import gleam/uri

const comment_start: String = "#"

const wildcard_glob: String = "*"

const wildcard_agent: String = "*"

const directive_separator: String = ":"

const anchor: String = "$"

const bom: String = "\u{FEFF}"

// equals 500KiB the RFC spec allows to parse
const parse_limit: Int = 512_000

/// The parsed state of a `robots.txt` response
pub opaque type Policy {
  /// A parsed `robots.txt` ruleset including sitemaps
  Rules(groups: dict.Dict(String, Group), sitemaps: List(uri.Uri))
  /// A policy to allow every request  for a given host at any rate
  AllowAll
  /// A policy to disallow any request for a given host
  DisallowAll
}

pub type Error {
  /// The server answered with a HTTP status code of 429 and requests you to
  /// slow down
  RateLimited(retry_after: option.Option(RetryAfter))
  /// The status code was outside the 2XX, 4XX or 5XX range
  UnexpectedHttpStatusCode(status_code: Int)
}

pub type RetryAfter {
  /// The amount of seconds you have to wait until you can make the next
  /// request
  Delay(seconds: Int)
  /// The datetime you are allowed to make the next request
  At(timestamp: timestamp.Timestamp)
}

pub type Rate {
  /// The rate in which you are allowed to make requests.
  /// Use `interval` to calculate an average request rate.
  Rate(requests: Int, seconds: Float)
}

type Directive {
  UserAgent(String)
  Rule(Rule)
  Sitemap(uri.Uri)
  Extension(String, String)
}

type Group {
  Group(rules: List(Rule), extensions: dict.Dict(String, String))
}

type Rule {
  Allow(pattern: Pattern)
  Disallow(pattern: Pattern)
}

type Pattern {
  Glob(segments: List(String), anchored: Bool, len: Int)
}

type State {
  State(
    agents: List(String),
    rules: List(Rule),
    groups: dict.Dict(String, Group),
    sitemaps: List(uri.Uri),
    extensions: dict.Dict(String, String),
    flush: Bool,
  )
}

/// Parses the content of a `robots.txt` file
///
/// It needs the HTTP status code because depending on the returned status code
///  the result can either be allow all or disallow all if the status code is
/// not in the 200 range.
/// 
/// A HTTP status code 429 will return a `RateLimited` error.
///
/// A HTTP status code of 3XX will return an `UnexpectedHttpStatusCode`. You
/// should follow redirects before parsing. The recommendation is to follow up
/// to five redirects before giving up. You can use `allow_all` or
/// `disallow_all` to construct a `Policy` in that case.
///
/// ## Examples
///
/// Outside the 200 range the body is ignored entirely:
///
/// ```gleam parse
/// assert grip.parse("Disallow: /", 404) == Ok(grip.allow_all())
/// assert grip.parse("Disallow: /", 503) == Ok(grip.disallow_all())
/// assert grip.parse("", 429) == Error(grip.RateLimited(option.None))
/// ```
pub fn parse(content: String, http_status_code: Int) -> Result(Policy, Error) {
  use <- check_status_code(http_status_code)
  content
  |> string.remove_prefix(bom)
  |> string.split("\n")
  |> within_parse_limit
  |> list.map(string.trim)
  |> list.filter_map(parse_line)
  |> list.fold(new_state(), step)
  |> flush()
  |> to_policy()
  |> Ok()
}

fn within_parse_limit(lines: List(String)) -> List(String) {
  list.fold_until(lines, #(0, []), fn(acc, line) {
    let #(bytes, kept) = acc
    // +1 for the newline we already split on
    let size = bytes + string.byte_size(line) + 1
    case size > parse_limit {
      True -> list.Stop(acc)
      False -> list.Continue(#(size, [line, ..kept]))
    }
  })
  |> pair.second
  |> list.reverse
}

/// Parses the rules from a given HTTP response
/// 
/// A HTTP status code 429 will return a `RateLimited` error and will try to
/// extract `retry-after` from the header if available.
/// 
/// A HTTP status code of 3XX will return an `UnexpectedHttpStatusCode`.
/// You should follow redirects before parsing. The recommendation is to follow
/// up to five redirects before giving up.
pub fn from_response(
  response: response.Response(String),
) -> Result(Policy, Error) {
  case parse(response.body, response.status) {
    Error(RateLimited(_)) -> {
      let retry_after =
        response.get_header(response, "retry-after")
        |> result.try(parse_retry_after)
        |> option.from_result()
      Error(RateLimited(retry_after: retry_after))
    }
    other -> other
  }
}

fn parse_retry_after(value: String) -> Result(RetryAfter, Nil) {
  let value = string.trim(value)
  parse_delay(value)
  |> result.lazy_or(fn() { parse_http_date(value) })
}

fn parse_delay(value: String) -> Result(RetryAfter, Nil) {
  case int.parse(value) {
    Ok(delay) if delay >= 0 -> Ok(Delay(delay))
    _ -> Error(Nil)
  }
}

fn parse_http_date(value: String) -> Result(RetryAfter, Nil) {
  value |> timestamp.parse_http_date |> result.map(At)
}

/// Checks if a given agent is allowed to access the requested URL
///
/// Only the path and query are matched. The scheme and host are ignored, so
/// you are responsible for passing the policy that belongs to the URL's
/// origin (see `grip/origin`).
///
/// This just evaluates allowed/disallowed directives and does NOT include any
/// rate limiting extensions.
///
/// ## Examples
///
/// Rules are matched longest first, so a more specific `Allow` beats a
/// broader `Disallow`:
///
/// ```gleam precedence
/// let assert Ok(policy) =
///   "User-Agent: *
///   Disallow: /
///   Allow: /public/"
///   |> grip.parse(200)
/// 
/// let assert Ok(public) = uri.parse("/public/report.html")
/// let assert Ok(private) = uri.parse("/private/report.html")
/// 
/// assert grip.is_allowed(policy, "LucyBot", public) == True
/// assert grip.is_allowed(policy, "LucyBot", private) == False
/// ```
///
/// The agent matching is case insensitive substring matching. If multiple
/// groups match, the one with the longest substring match wins.
///
/// ```gleam product_token
/// let assert Ok(policy) =
///   "User-Agent: LucyBot
///   Disallow: /"
///   |> grip.parse(200)
/// 
/// let assert Ok(url) = uri.parse("/x")
/// 
/// assert grip.is_allowed(policy, "LucyBot", url) == False
/// assert grip.is_allowed(policy, "LucyBot/2.1", url) == False
/// assert grip.is_allowed(policy, "GleamBot", url) == True
/// ```
pub fn is_allowed(policy: Policy, agent: String, url: uri.Uri) -> Bool {
  let path = case url.path {
    "" -> "/"
    other -> other
  }

  let path = case url.query {
    option.Some(query) -> path <> "?" <> query
    option.None -> path
  }

  let path = encode_url(path)

  case policy {
    AllowAll -> True
    DisallowAll -> False
    Rules(..) -> {
      case
        group_for(policy, agent)
        |> result.try(fn(group) { find_rule(group.rules, path) })
      {
        Ok(Disallow(_)) -> False
        _ -> True
      }
    }
  }
}

/// Returns the crawl delay if specified for this user agent
///
/// It is recommended to use `rate` to get the safe result comparing crawl
/// delay and request rate directives.
pub fn crawl_delay(policy: Policy, agent: String) -> Result(Rate, Nil) {
  extension(policy, agent, "crawl-delay", parse_crawl_delay)
}

/// Returns the request rate if specified for this user agent
///
/// It is recommended to use `rate` to get the safe result comparing
/// crawl delay and request rate directives.
pub fn request_rate(policy: Policy, agent: String) -> Result(Rate, Nil) {
  extension(policy, agent, "request-rate", parse_request_rate)
}

/// Checks both crawl delay and request rate and returns the slower one
///
/// ## Examples
///
/// One request per 10 seconds is slower than one every 2, so the request rate
/// wins:
///
/// ```gleam rate
/// let assert Ok(policy) =
///   "User-Agent: *
///   Crawl-Delay: 2
///   Request-Rate: 1/10"
///   |> grip.parse(200)
/// 
/// assert grip.rate(policy, "LucyBot") == Ok(grip.Rate(1, 10.0))
/// ```
pub fn rate(policy: Policy, agent: String) -> Result(Rate, Nil) {
  case crawl_delay(policy, agent), request_rate(policy, agent) {
    Ok(delay), Ok(rate) ->
      case interval(delay) >. interval(rate) {
        True -> Ok(delay)
        False -> Ok(rate)
      }
    Error(_), Ok(rate) | Ok(rate), Error(_) -> Ok(rate)
    _, _ -> Error(Nil)
  }
}

/// Convert a rate into an interval
///
/// This normalizes the rate into a float average to send each request.
/// This avoids bursts and distributes the requests politely.
///
/// ## Examples
///
/// ```gleam interval
/// let rate = grip.Rate(requests: 2, seconds: 10.0)
/// assert grip.interval(rate) == 5.0
/// ```
pub fn interval(rate: Rate) -> Float {
  rate.seconds /. int.to_float(rate.requests)
}

/// Returns the found sitemap urls
///
/// If any sitemap could not be parsed to an `uri.Uri` it will be ignored.
pub fn sitemaps(policy: Policy) -> List(uri.Uri) {
  case policy {
    Rules(sitemaps:, ..) -> sitemaps
    AllowAll | DisallowAll -> []
  }
}

/// A policy that permits every URL.
///
/// Per [`RFC 9309 §2.3.1.3`](https://www.rfc-editor.org/rfc/rfc9309#section-2.3.1.3),
/// use this when `robots.txt` is *unavailable*: a 4XX response, or more
/// than five consecutive redirects. Also suitable when the file has been
/// unreachable for over 30 days with no cached copy.
pub fn allow_all() -> Policy {
  AllowAll
}

/// A policy that permits no URL.
///
/// Per [`RFC 9309 §2.3.1.4`](https://www.rfc-editor.org/rfc/rfc9309#section-2.3.1.4),
/// use this when `robots.txt` is *unreachable*: a 5XX response, or a
/// transport failure such as DNS resolution, connection refused, or timeout,
/// where no HTTP status code exists.
pub fn disallow_all() -> Policy {
  DisallowAll
}

fn find_rule(rules: List(Rule), path: String) -> Result(Rule, Nil) {
  list.find(rules, match_rule(_, path))
}

fn match_rule(rule: Rule, path: String) -> Bool {
  case rule.pattern.segments, rule.pattern.anchored {
    [], _ -> True
    [segment, ..remaining], anchored -> {
      string.starts_with(path, segment)
      && match_segments(
        remaining,
        anchored,
        string.remove_prefix(path, segment),
      )
    }
  }
}

fn skip_past(path: String, segment: String) -> Result(String, Nil) {
  case segment {
    "" -> Ok(path)
    _ -> string.split_once(path, segment) |> result.map(pair.second)
  }
}

fn match_segments(
  segments: List(String),
  anchored: Bool,
  path: String,
) -> Bool {
  case segments {
    [] -> !anchored || path == ""
    [last] if anchored -> string.ends_with(path, last)
    [segment, ..remaining] -> {
      case skip_past(path, segment) {
        Ok(rest) -> match_segments(remaining, anchored, rest)
        Error(_) -> False
      }
    }
  }
}

fn group_for(policy: Policy, agent: String) -> Result(Group, Nil) {
  case policy {
    AllowAll | DisallowAll -> Error(Nil)
    Rules(groups:, ..) -> {
      groups
      |> find_by_agent(agent)
      |> result.lazy_or(fn() { dict.get(groups, wildcard_agent) })
    }
  }
}

fn find_by_agent(
  groups: dict.Dict(String, Group),
  agent: String,
) -> Result(Group, Nil) {
  let agent = string.lowercase(agent)

  dict.fold(groups, Error(Nil), fn(best, token, group) {
    use <- bool.guard(token == wildcard_agent, best)
    use <- bool.guard(!string.contains(agent, token), best)
    let len = string.length(token)
    case best {
      Ok(#(best_len, _)) if best_len >= len -> best
      _ -> Ok(#(len, group))
    }
  })
  |> result.map(pair.second)
}

/// Returns the raw parsed extensions from the policy
///
/// Keys are the lowercased directive names, values the raw unparsed strings:
/// `Lang: Gleam` becomes `#("lang", "Gleam")`.
pub fn extensions(
  policy: Policy,
  agent: String,
) -> Result(dict.Dict(String, String), Nil) {
  policy
  |> group_for(agent)
  |> result.map(fn(group) { group.extensions })
}

fn extension(
  policy: Policy,
  agent: String,
  key: String,
  parse: fn(String) -> Result(a, Nil),
) -> Result(a, Nil) {
  policy
  |> extensions(agent)
  |> result.try(dict.get(_, key))
  |> result.try(parse)
}

fn new_state() -> State {
  State(
    agents: [],
    rules: [],
    groups: dict.new(),
    sitemaps: [],
    flush: False,
    extensions: dict.new(),
  )
}

fn step(state: State, directive: Directive) -> State {
  case directive {
    UserAgent(agent) -> {
      case state.flush {
        False -> State(..state, agents: [agent, ..state.agents])
        True -> {
          let state = flush(state)
          State(..state, agents: [agent])
        }
      }
    }
    Rule(rule) -> State(..state, rules: [rule, ..state.rules], flush: True)
    Sitemap(sitemap) -> State(..state, sitemaps: [sitemap, ..state.sitemaps])
    Extension(name, value) ->
      case state.agents {
        [] -> state
        _ -> {
          State(..state, extensions: dict.insert(state.extensions, name, value))
        }
      }
  }
}

fn flush(state: State) -> State {
  let groups =
    list.fold(state.agents, state.groups, fn(groups, agent) {
      let existing =
        dict.get(groups, agent)
        |> result.unwrap(Group(rules: [], extensions: dict.new()))

      let rules =
        state.rules |> list.append(existing.rules) |> list.reverse |> sort_rules

      let group =
        Group(
          rules:,
          extensions: dict.merge(existing.extensions, state.extensions),
        )
      dict.insert(groups, agent, group)
    })
  State(..new_state(), sitemaps: state.sitemaps, groups:)
}

fn sort_rules(rules: List(Rule)) -> List(Rule) {
  list.sort(rules, fn(left, right) {
    int.compare(right.pattern.len, left.pattern.len)
    |> order.break_tie(case left, right {
      Allow(_), Disallow(_) -> order.Lt
      Disallow(_), Allow(_) -> order.Gt
      _, _ -> order.Eq
    })
  })
}

fn to_policy(state: State) -> Policy {
  Rules(groups: state.groups, sitemaps: state.sitemaps)
}

fn check_status_code(
  code: Int,
  continue: fn() -> Result(Policy, Error),
) -> Result(Policy, Error) {
  case code {
    code if code == 429 -> Error(RateLimited(option.None))
    code if code >= 200 && code <= 299 -> continue()
    code if code >= 400 && code <= 499 -> Ok(AllowAll)
    code if code >= 500 && code <= 599 -> Ok(DisallowAll)
    code -> Error(UnexpectedHttpStatusCode(code))
  }
}

fn parse_line(line: String) -> Result(Directive, Nil) {
  let line = before(line, comment_start)
  use <- bool.guard(line == "", Error(Nil))

  use #(key, value) <- result.try(string.split_once(line, directive_separator))
  let value = string.trim(value)
  case key |> string.trim |> string.lowercase {
    "user-agent" -> parse_user_agent(value)
    "allow" -> {
      let glob = parse_pattern(value)
      Ok(Rule(Allow(glob)))
    }
    "disallow" | "dissallow" | "disalow" -> {
      let glob = parse_pattern(value)
      case value {
        // empty disallow is transformed to an allow all
        "" -> Ok(Rule(Allow(Glob([], False, 0))))
        _ -> Ok(Rule(Disallow(glob)))
      }
    }
    "sitemap" | "site-map" -> parse_sitemap(value)
    name -> Ok(Extension(name, value))
  }
}

fn parse_pattern(value: String) -> Pattern {
  let anchored = string.ends_with(value, anchor)
  let value = string.remove_suffix(value, anchor)
  let segments = string.split(value, wildcard_glob) |> list.map(encode_url)
  let len = segments |> string.concat |> string.length()
  Glob(segments, anchored, len)
}

fn encode_url(segment: String) -> String {
  segment
  |> string.to_graphemes
  |> list.map(escape_grapheme)
  |> string.concat
}

fn escape_grapheme(grapheme: String) -> String {
  case is_safe(grapheme) {
    True -> grapheme
    False -> uri.percent_encode(grapheme)
  }
}

const unsafe_ascii: List(String) = [
  "\"",
  "<",
  ">",
  "|",
  "^",
  "`",
  "{",
  "}",
  "\\",
]

fn is_safe(grapheme: String) -> Bool {
  case string.to_utf_codepoints(grapheme) {
    [codepoint] -> {
      let ascii = string.utf_codepoint_to_int(codepoint)
      ascii > 32 && ascii < 127 && !list.contains(unsafe_ascii, grapheme)
    }
    _ -> False
  }
}

fn parse_user_agent(value: String) -> Result(Directive, Nil) {
  case value {
    value if value == wildcard_agent -> Ok(UserAgent(wildcard_agent))
    _ -> {
      case
        value
        |> string.to_graphemes()
        |> list.take_while(is_product_token_grapheme)
        |> string.concat
      {
        "" -> Error(Nil)
        value -> {
          value
          |> string.lowercase
          |> UserAgent
          |> Ok
        }
      }
    }
  }
}

fn is_product_token_grapheme(grapheme: String) -> Bool {
  case string.to_utf_codepoints(grapheme) {
    [codepoint] -> {
      let ascii = string.utf_codepoint_to_int(codepoint)
      ascii == 0x2D
      || ascii == 0x5F
      || { ascii >= 0x41 && ascii <= 0x5A }
      || { ascii >= 0x61 && ascii <= 0x7A }
    }
    _ -> False
  }
}

fn parse_sitemap(value: String) -> Result(Directive, Nil) {
  value |> uri.parse |> result.map(Sitemap)
}

fn parse_crawl_delay(value: String) -> Result(Rate, Nil) {
  value |> parse_seconds |> result.map(Rate(1, _))
}

fn parse_request_rate(value: String) -> Result(Rate, Nil) {
  use #(requests, seconds) <- result.try(string.split_once(value, "/"))
  use requests <- result.try(requests |> string.trim |> int.parse)
  parse_seconds(seconds) |> result.map(Rate(requests, _))
}

fn parse_seconds(value: String) -> Result(Float, Nil) {
  value
  |> float.parse
  |> result.lazy_or(fn() { int.parse(value) |> result.map(int.to_float) })
}

fn before(value: String, separator: String) -> String {
  case string.split_once(value, separator) {
    Ok(#(left, _)) -> left
    Error(_) -> value
  }
}
