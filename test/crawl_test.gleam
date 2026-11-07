import gleam/dict
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/result
import gleam/uri
import grip
import grip/origin

pub fn crawl_test() {
  let assert Ok(target) = uri.parse("https://example.com/private/secret.txt")
  let assert Ok(request) = request.from_uri(target)
  let origin = origin.from_request(request)
  let _robots_url = origin.robots_url(origin)

  // here you would fetch the `robots_url`
  // we simulate a response to not do a real network request

  let robots_response =
    response.new(200)
    |> response.set_body(
      "User-Agent: *
      Disallow: /private/
      Crawl-Delay: 2
      Request-Rate: 2/5
      Sitemap: https://example.com/sitemap.xml
      Lang: Gleam",
    )

  let assert Ok(policy) = grip.from_response(robots_response)

  assert grip.is_allowed(policy, "LucyBot", target) == False
  assert grip.rate(policy, "LucyBot") |> result.map(grip.interval) == Ok(2.5)
  assert grip.sitemaps(policy) |> list.length() == 1
  assert grip.extensions(policy, "LucyBot") |> result.try(dict.get(_, "lang"))
    == Ok("Gleam")

  // links found on the page only follow this policy if they stay on the origin

  let assert Ok(link) = uri.parse("https://example.com/public/index.html")
  let assert Ok(offsite) = uri.parse("https://cdn.example.com/assets/logo.png")

  assert origin.covers(origin, link) == True
  assert origin.covers(origin, offsite) == False
}
