defmodule FrancisTemplate.EEx do
  @moduledoc """
  Default template engine backed by Elixir's built-in `EEx`.

  Templates are plain `.eex` files. Assigns are exposed through the `@` syntax:

      <h1>Hello <%= @name %></h1>

  ## Escaping

  `EEx` does **not** escape interpolated values, so this engine carries the same
  caveat as `Francis.ResponseHandlers.html/2`: escape untrusted input with
  `Francis.HTML.escape/1` inside the template.

      <p>Bio: <%= Francis.HTML.escape(@bio) %></p>

  This keeps escaping an explicit concern of the caller, consistent with the
  rest of Francis. If you need auto-escaping, register an engine that wraps an
  escaping EEx engine (e.g. `Phoenix.HTML.Engine`) so the dependency stays in
  your app — see `FrancisTemplate.Engine`.
  """

  @behaviour FrancisTemplate.Engine

  # `path` is a template path chosen by the developer (a route handler picks
  # which template to render), not untrusted user input — evaluating it with EEx
  # is the whole point of a template engine.
  # sobelow_skip ["RCE.EEx"]
  @impl true
  @spec render(String.t(), map() | keyword()) :: binary()
  def render(path, assigns) do
    EEx.eval_file(path, assigns: normalize(assigns))
  end

  defp normalize(assigns) when is_map(assigns), do: Map.to_list(assigns)
  defp normalize(assigns) when is_list(assigns), do: assigns
end
