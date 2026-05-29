# FrancisTemplate

File-based templates with layouts and pluggable engines for the
[Francis](https://hex.pm/packages/francis) micro-framework.

Francis ships response helpers like `html/2`, `json/2` and `text/2`, and the
companion [`francis_htmx`](https://hex.pm/packages/francis_htmx) renders EEx
*inline* with the `~E` sigil. `francis_template` fills the other gap: rendering
templates from **separate files** on disk, wrapping them in **layouts**, and
choosing the renderer by file extension so you can swap in **other engines**
(e.g. Liquid via [Solid](https://hex.pm/packages/solid)).

It depends only on `francis` — no `phoenix_html`, no heavy view layer.

## Installation

```elixir
def deps do
  [
    {:francis, "~> 0.1"},
    {:francis_template, "~> 0.1"}
  ]
end
```

## Usage

```elixir
defmodule MyApp do
  use Francis
  use FrancisTemplate

  # priv/templates/index.html.eex => <h1>Hello <%= @name %></h1>
  get("/", fn conn -> render(conn, "index.html.eex", name: "World") end)
end
```

`use FrancisTemplate` imports `render/2,3,4` (sends a 200 HTML response) and
`render_to_string/1,2,3` (returns a binary), so they read like the other Francis
helpers. You can also call `FrancisTemplate.render/4` fully qualified.

Templates are read from `priv/templates` by default; the engine is picked from
the file extension (`.eex` out of the box).

## Layouts

A layout is an ordinary template that wraps the rendered content, exposed to it
as the `@inner_content` assign. A `layout.html.eex` at the template root is
applied to **every** render automatically — no configuration needed:

```eex
<%# priv/templates/layout.html.eex %>
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>My Site</title>
    <link rel="stylesheet" href="/app.css" />
    <%# analytics / other <head> tags go here %>
  </head>
  <body>
    <%= @inner_content %>
  </body>
</html>
```

Override per render, or skip a configured layout:

```elixir
render(conn, "index.html.eex", [name: "World"], layout: "admin.html.eex")
render(conn, "index.html.eex", [name: "World"], layout: false)
```

Assigns flow to both the content template and the layout, so a layout can use
`<%= @title %>` alongside `<%= @inner_content %>`.

## Serving plain static pages

Even with no `<%= %>` tags, an `.html.eex` file is just static HTML. Drop your
pages in `priv/templates`, share one `layout.html.eex` for the `<head>`, and map
routes to them:

```elixir
get("/",        fn conn -> render(conn, "index.html.eex") end)
get("/about",   fn conn -> render(conn, "about.html.eex") end)
get("/contact", fn conn -> render(conn, "contact.html.eex") end)
```

When you later add dynamic data (e.g. presence counts), pass assigns —
no restructuring required.

## Custom engines (Liquid / Solid, ...)

Implement `FrancisTemplate.Engine` and register it for an extension. This is
handy if you also write Shopify themes and want to reuse Liquid:

```elixir
defmodule MyApp.LiquidEngine do
  @behaviour FrancisTemplate.Engine

  @impl true
  def render(path, assigns) do
    path
    |> File.read!()
    |> Solid.parse!()
    |> Solid.render!(stringify_keys(assigns))
    |> to_string()
  end

  defp stringify_keys(assigns),
    do: Map.new(assigns, fn {k, v} -> {to_string(k), v} end)
end
```

```elixir
# config/config.exs
config :francis_template, engines: %{"liquid" => MyApp.LiquidEngine}
```

Now `render(conn, "page.liquid", products: products)` renders with Solid, while
`.eex` files keep using the built-in engine.

## Escaping

The default `FrancisTemplate.EEx` engine does **not** auto-escape — escaping is
the template's concern, consistent with `Francis.ResponseHandlers.html/2`.
Escape untrusted assigns with `Francis.HTML.escape/1` (shipped with Francis,
zero extra deps) inside the template:

```eex
<p>Bio: <%= Francis.HTML.escape(@bio) %></p>
```

If you want auto-escaping everywhere, register an engine that wraps an escaping
EEx engine (e.g. `Phoenix.HTML.Engine`) — that keeps the dependency in your app
rather than in this package.

## Configuration

```elixir
config :francis_template,
  # directory templates are read from (default "priv/templates")
  root: "priv/templates",
  # extra/override engines, merged over %{"eex" => FrancisTemplate.EEx}
  engines: %{"liquid" => MyApp.LiquidEngine},
  # layout wrapping every render; defaults to "layout.html.eex" if it exists
  layout: "base.html.eex"
```

In a release, set `:root` to an absolute path
(`Application.app_dir(:my_app, "priv/templates")`) since `priv` — not the
directory's relative location — is what ships.

## License

MIT
