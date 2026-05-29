defmodule FrancisTemplate.Engine do
  @moduledoc """
  Behaviour for pluggable template engines.

  An engine receives the path to a template file and the assigns to render it
  with, and returns the rendered output as iodata (a binary is valid iodata).

  The default engine is `FrancisTemplate.EEx`, registered for the `.eex`
  extension. Engines are resolved per-template by file extension, so multiple
  engines can coexist in the same application.

  To use a different engine — for example an adapter for a Liquid implementation
  such as [Solid](https://hex.pm/packages/solid), which is handy if you also
  write Shopify themes — implement this behaviour and register it for an
  extension:

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

      # config/config.exs
      config :francis_template, engines: %{"liquid" => MyApp.LiquidEngine}

  Note that engines differ in how they interpret `assigns`: `FrancisTemplate.EEx`
  expects atom-keyed assigns exposed through the `@` syntax, while a Liquid
  engine expects string-keyed data. Normalising the assigns is the engine's
  concern.
  """

  @callback render(path :: String.t(), assigns :: map() | keyword()) :: iodata()
end
