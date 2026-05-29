defmodule FrancisTemplateTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias FrancisTemplate.Support.UpcaseEngine

  @root "test/fixtures/templates"

  setup do
    prev_root = Application.get_env(:francis_template, :root)
    prev_engines = Application.get_env(:francis_template, :engines)
    prev_layout = Application.get_env(:francis_template, :layout)
    Application.put_env(:francis_template, :root, @root)

    on_exit(fn ->
      restore(:root, prev_root)
      restore(:engines, prev_engines)
      restore(:layout, prev_layout)
    end)

    :ok
  end

  defp restore(key, nil), do: Application.delete_env(:francis_template, key)
  defp restore(key, val), do: Application.put_env(:francis_template, key, val)

  describe "render_to_string/2 with the default EEx engine" do
    test "renders with keyword assigns" do
      assert FrancisTemplate.render_to_string("greeting.html.eex", name: "World") ==
               "<h1>Hello World</h1>"
    end

    test "renders with map assigns" do
      assert FrancisTemplate.render_to_string("greeting.html.eex", %{name: "Jo"}) ==
               "<h1>Hello Jo</h1>"
    end

    test "does not auto-escape — escaping is the template's concern" do
      assert FrancisTemplate.render_to_string("greeting.html.eex", name: "<b>") ==
               "<h1>Hello <b></h1>"
    end

    test "raises for an unregistered extension" do
      assert_raise ArgumentError, ~r/no template engine registered/, fn ->
        FrancisTemplate.render_to_string("unknown.foo")
      end
    end
  end

  describe "layouts" do
    test "renders without a layout when no layout.html.eex is present" do
      # @root has no file named layout.html.eex, so the convention does not fire
      assert FrancisTemplate.render_to_string("greeting.html.eex", name: "World") ==
               "<h1>Hello World</h1>"
    end

    @tag :tmp_dir
    test "applies a layout.html.eex at the template root by convention", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "layout.html.eex"), "<main><%= @inner_content %></main>")
      File.write!(Path.join(dir, "index.html.eex"), "<p><%= @msg %></p>")
      Application.put_env(:francis_template, :root, dir)

      assert FrancisTemplate.render_to_string("index.html.eex", msg: "hi") ==
               "<main><p>hi</p></main>"

      assert FrancisTemplate.render_to_string("index.html.eex", [msg: "hi"], layout: false) ==
               "<p>hi</p>"
    end

    test "wraps content in the layout configured via :layout" do
      Application.put_env(:francis_template, :layout, "app.html.eex")

      assert FrancisTemplate.render_to_string("greeting.html.eex", name: "World") ==
               "<main><h1>Hello World</h1></main>"
    end

    test "per-render :layout overrides the configured layout" do
      Application.put_env(:francis_template, :layout, "app.html.eex")

      assert FrancisTemplate.render_to_string("greeting.html.eex", [name: "World"],
               layout: "fancy.html.eex"
             ) ==
               "<section><h1>Hello World</h1></section>"
    end

    test "layout: false skips a configured layout" do
      Application.put_env(:francis_template, :layout, "app.html.eex")

      assert FrancisTemplate.render_to_string("greeting.html.eex", [name: "World"], layout: false) ==
               "<h1>Hello World</h1>"
    end

    test "assigns are available to both the content and the layout" do
      assert FrancisTemplate.render_to_string("greeting.html.eex", [name: "World"],
               layout: "titled.html.eex"
             ) ==
               "<title>World</title><main><h1>Hello World</h1></main>"
    end

    test "the layout's engine is resolved independently of the content's engine" do
      Application.put_env(:francis_template, :engines, %{"up" => UpcaseEngine})

      assert FrancisTemplate.render_to_string("shout.up", %{}, layout: "app.html.eex") ==
               "<main>HELLO</main>"
    end
  end

  describe "pluggable engines (the swappability seam)" do
    test "dispatches to a custom engine registered by extension" do
      Application.put_env(:francis_template, :engines, %{"up" => UpcaseEngine})
      assert FrancisTemplate.render_to_string("shout.up") == "HELLO"
    end
  end

  describe "render/4 (the conn response helper)" do
    test "renders a template into a 200 HTML response" do
      conn =
        :get
        |> conn("/")
        |> FrancisTemplate.render("greeting.html.eex", name: "World")

      assert conn.status == 200
      assert conn.resp_body == "<h1>Hello World</h1>"
      assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
    end

    test "wraps the response in a layout passed via opts" do
      conn =
        :get
        |> conn("/")
        |> FrancisTemplate.render("greeting.html.eex", [name: "World"], layout: "app.html.eex")

      assert conn.resp_body == "<main><h1>Hello World</h1></main>"
    end
  end
end
