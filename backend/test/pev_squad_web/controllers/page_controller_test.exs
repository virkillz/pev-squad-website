defmodule PevSquadWeb.PageControllerTest do
  use PevSquadWeb.ConnCase

  test "GET / renders the home page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "PERS"
  end
end
