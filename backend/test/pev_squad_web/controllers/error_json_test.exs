defmodule PevSquadWeb.ErrorJSONTest do
  use PevSquadWeb.ConnCase, async: true

  test "renders 404 in the API error shape" do
    assert %{error: %{code: "not_found", message: _}} =
             PevSquadWeb.ErrorJSON.render("404.json", %{})
  end

  test "renders 500" do
    assert PevSquadWeb.ErrorJSON.render("500.json", %{}) ==
             %{error: %{code: "server_error", message: "Internal Server Error"}}
  end
end
