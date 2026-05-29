defmodule FrancisTemplate do
  @moduledoc """
  File-based templates with layouts and pluggable engines for
  [Francis](https://hex.pm/packages/francis).

  Templates live under a configurable root directory (default: `priv/templates`)
  and are rendered to a string. A route handler can return that string directly
  or, more commonly, send it with `render/4`, which sets the HTML headers for you.

  ## Usage

      defmodule MyApp do
        use Francis
        use FrancisTemplate

        # priv/templates/index.html.eex => <h1>Hello <%= @name %></h1>
        get("/", fn conn -> render(conn, "index.html.eex", name: "World") end)
      end

  `use FrancisTemplate` imports `render/2,3,4` and `render_to_string/1,2,3` so
  they read like the other Francis response helpers (`html/2`, `json/2`, ...).
  You can also call `FrancisTemplate.render/4` fully qualified without the
  `use`.

  ## Engines

  The engine is chosen from the template's file extension. The built-in engine,
  `FrancisTemplate.EEx`, handles `.eex` and is registered out of the box. Add or
  override engines with the `:engines` config — for example a Liquid engine
  backed by [Solid](https://hex.pm/packages/solid), handy if you also write
  Shopify themes. See `FrancisTemplate.Engine`.

  ## Layouts

  A layout is an ordinary template that wraps the rendered content, which is
  exposed to it as the `inner_content` assign:

      # priv/templates/layout.html.eex
      # <html><body><%= @inner_content %></body></html>

  A `layout.html.eex` at the template root is applied to every render
  automatically — no configuration required. Point `:layout` at a different file
  to change it, pass `:layout` per render to override, or pass `layout: false`
  to render without a layout:

      render(conn, "index.html.eex", [name: "World"], layout: false)

  Assigns flow to both the content template and the layout, so a layout can use
  `<%= @title %>` alongside `<%= @inner_content %>`. The layout's engine is
  resolved from its own extension, so it need not match the content's engine.
  Because the default EEx engine does not auto-escape, the already-rendered
  `inner_content` is spliced in verbatim.

  ## Escaping

  The default `FrancisTemplate.EEx` engine does **not** auto-escape — escaping is
  the template's concern, consistent with `Francis.ResponseHandlers.html/2`.
  Escape untrusted assigns with `Francis.HTML.escape/1` inside the template:

      <p>Bio: <%= Francis.HTML.escape(@bio) %></p>

  If you want auto-escaping everywhere, register an engine that wraps an
  escaping EEx engine (e.g. `Phoenix.HTML.Engine`); that keeps the dependency in
  your app rather than in this package.

  ## Configuration

    * `:root` — directory templates are read from. Defaults to
      `"priv/templates"`, resolved relative to the current working directory. In
      a release, set this to an absolute path (e.g.
      `Application.app_dir(:my_app, "priv/templates")`) since `priv` — not the
      directory's relative location — is what ships.
    * `:engines` — a map of file extension (without the dot) to an engine module
      implementing `FrancisTemplate.Engine`. Merged over the built-in
      `%{"eex" => FrancisTemplate.EEx}`.
    * `:layout` — the layout template (relative to `:root`) that wraps every
      render unless overridden per call. Defaults to `"layout.html.eex"` when
      that file exists, otherwise no layout.

      config :francis_template,
        engines: %{"liquid" => MyApp.LiquidEngine},
        layout: "base.html.eex"
  """

  @default_engines %{"eex" => FrancisTemplate.EEx}
  @default_root "priv/templates"
  @default_layout "layout.html.eex"

  @doc """
  Imports `render/2,3,4` and `render_to_string/1,2,3` into the calling module so
  they can be called bare alongside the other Francis response helpers.
  """
  defmacro __using__(_opts) do
    quote do
      import FrancisTemplate,
        only: [
          render: 2,
          render: 3,
          render: 4,
          render_to_string: 1,
          render_to_string: 2,
          render_to_string: 3
        ]
    end
  end

  @doc """
  Renders `template` and sends it as an HTML response with a 200 status code.

  `template` is a path relative to the configured template root and the engine
  is chosen from its file extension. `assigns` and `opts` are passed through to
  `render_to_string/3`.

  ## Examples

      get("/", fn conn -> render(conn, "index.html.eex", name: "World") end)
  """
  @spec render(Plug.Conn.t(), String.t(), map() | keyword(), keyword()) :: Plug.Conn.t()
  def render(conn, template, assigns \\ %{}, opts \\ []) do
    Francis.ResponseHandlers.html(conn, render_to_string(template, assigns, opts))
  end

  @doc """
  Renders `template` (a path relative to the template root) with `assigns` and
  returns the result as a binary.

  The engine is chosen from the template's file extension.

  ## Options

    * `:layout` — a layout template to wrap the result. Overrides the `:layout`
      config. Pass `false` to skip a configured layout. See the "Layouts"
      section in `FrancisTemplate`.
  """
  @spec render_to_string(String.t(), map() | keyword(), keyword()) :: binary()
  def render_to_string(template, assigns \\ %{}, opts \\ []) do
    inner = render_to_binary(template, assigns)

    case layout(opts) do
      nil -> inner
      layout -> render_to_binary(layout, put_inner(assigns, inner))
    end
  end

  defp render_to_binary(template, assigns) do
    path = full_path(template)
    engine = engine_for(path)

    path
    |> engine.render(assigns)
    |> IO.iodata_to_binary()
  end

  defp layout(opts) do
    case Keyword.get(opts, :layout, :default) do
      :default -> default_layout()
      false -> nil
      layout -> layout
    end
  end

  # A layout configured via `:layout` (or passed per render) is used as given.
  # Absent that, a `layout.html.eex` at the template root is used by convention
  # when it exists — so layouts work with no configuration.
  defp default_layout do
    case Application.get_env(:francis_template, :layout) do
      nil -> if File.exists?(full_path(@default_layout)), do: @default_layout
      layout -> layout
    end
  end

  defp put_inner(assigns, inner) when is_map(assigns), do: Map.put(assigns, :inner_content, inner)

  defp put_inner(assigns, inner) when is_list(assigns),
    do: Keyword.put(assigns, :inner_content, inner)

  defp full_path(template) do
    :francis_template
    |> Application.get_env(:root, @default_root)
    |> Path.join(template)
  end

  defp engine_for(path) do
    ext = path |> Path.extname() |> String.trim_leading(".")
    engines = Map.merge(@default_engines, Application.get_env(:francis_template, :engines, %{}))

    case Map.fetch(engines, ext) do
      {:ok, engine} ->
        engine

      :error ->
        raise ArgumentError,
              "no template engine registered for extension #{inspect(ext)} " <>
                "(template: #{inspect(path)})"
    end
  end
end
