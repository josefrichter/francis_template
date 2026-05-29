defmodule FrancisTemplate.Support.UpcaseEngine do
  @moduledoc false
  # A trivial engine used in tests to prove that dispatch is extension-based and
  # engines are swappable. It ignores assigns and upcases the raw file contents.
  @behaviour FrancisTemplate.Engine

  @impl true
  def render(path, _assigns), do: path |> File.read!() |> String.upcase()
end
