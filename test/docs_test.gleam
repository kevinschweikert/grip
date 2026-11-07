import checkmark
import envoy
import simplifile

pub fn readme_test() {
  let checker = checkmark.new(simplifile.read, simplifile.write)
  let assert Ok(snippets) =
    checkmark.load_snippet_source(checker, "./test/examples_test.gleam")

  assert checker
    |> checkmark.document("README.md")
    |> checkmark.should_contain_snippet_from(
      snippets,
      checkmark.FunctionBody("readme_usage_test"),
      tagged: "usage",
    )
    |> checkmark.should_contain_contents_of(
      "./test/crawl_test.gleam",
      tagged: "gleam crawl",
    )
    |> checkmark.check_or_update(when: envoy.get("CI") == Error(Nil))
    == Ok(Nil)
}

pub fn doc_comments_test() {
  let checker = checkmark.new(simplifile.read, simplifile.write)
  let assert Ok(snippets) =
    checkmark.load_snippet_source(checker, "./test/examples_test.gleam")

  assert checker
    |> checkmark.comments_in("./src/grip.gleam")
    |> checkmark.should_contain_snippet_from(
      snippets,
      checkmark.FunctionBody("parse_example_test"),
      tagged: "parse",
    )
    |> checkmark.should_contain_snippet_from(
      snippets,
      checkmark.FunctionBody("precedence_example_test"),
      tagged: "precedence",
    )
    |> checkmark.should_contain_snippet_from(
      snippets,
      checkmark.FunctionBody("product_token_example_test"),
      tagged: "product_token",
    )
    |> checkmark.should_contain_snippet_from(
      snippets,
      checkmark.FunctionBody("rate_example_test"),
      tagged: "rate",
    )
    |> checkmark.should_contain_snippet_from(
      snippets,
      checkmark.FunctionBody("interval_example_test"),
      tagged: "interval",
    )
    |> checkmark.check_or_update(when: envoy.get("CI") == Error(Nil))
    == Ok(Nil)
}

pub fn origin_doc_comments_test() {
  let checker = checkmark.new(simplifile.read, simplifile.write)
  let assert Ok(snippets) =
    checkmark.load_snippet_source(checker, "./test/examples_test.gleam")

  assert checker
    |> checkmark.comments_in("./src/grip/origin.gleam")
    |> checkmark.should_contain_snippet_from(
      snippets,
      checkmark.FunctionBody("robots_url_example_test"),
      tagged: "robots_url",
    )
    |> checkmark.check_or_update(when: envoy.get("CI") == Error(Nil))
    == Ok(Nil)
}
