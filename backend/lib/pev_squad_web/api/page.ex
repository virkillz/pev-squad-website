defmodule PevSquadWeb.API.Page do
  @moduledoc """
  Pagination for public lists: `?limit=20&after=<cursor>`, answered with
  `{"data": [...], "next": "<cursor>" | null}`.

  Cursors are opaque to clients. Today they wrap an offset, which is fine
  for lists this size; they can switch to keyset cursors later without the
  app noticing.
  """
  use Gettext, backend: PevSquadWeb.Gettext

  @default_limit 20
  @max_limit 50

  defstruct limit: @default_limit, offset: 0

  @doc "Reads `limit` and `after`. Returns `{:ok, page}` or a validation error."
  def from_params(params) do
    with {:ok, limit} <- limit(params["limit"]),
         {:ok, offset} <- decode(params["after"]) do
      {:ok, %__MODULE__{limit: limit, offset: offset}}
    end
  end

  @doc "Pages a list that's already in memory. Returns `{items, next}`."
  def slice(list, %__MODULE__{limit: limit, offset: offset} = page) do
    rest = Enum.drop(list, offset)
    {items, more} = Enum.split(rest, limit)
    {items, if(more == [], do: nil, else: next(page))}
  end

  @doc """
  For queries run with `limit: page.limit + 1, offset: page.offset`: drops
  the extra row and says whether there's a next page.
  """
  def trim(rows, %__MODULE__{limit: limit} = page) do
    if length(rows) > limit, do: {Enum.take(rows, limit), next(page)}, else: {rows, nil}
  end

  defp next(%__MODULE__{limit: limit, offset: offset}),
    do: Base.url_encode64("o:#{offset + limit}", padding: false)

  defp limit(nil), do: {:ok, @default_limit}

  defp limit(value) do
    case Integer.parse(to_string(value)) do
      {n, ""} when n in 1..@max_limit -> {:ok, n}
      _ -> error("limit", gettext("must be a number from 1 to %{max}", max: @max_limit))
    end
  end

  defp decode(nil), do: {:ok, 0}
  defp decode(""), do: {:ok, 0}

  defp decode(cursor) do
    with {:ok, "o:" <> n} <- Base.url_decode64(cursor, padding: false),
         {offset, ""} when offset >= 0 <- Integer.parse(n) do
      {:ok, offset}
    else
      _ -> error("after", gettext("isn't a cursor from this API"))
    end
  end

  defp error(field, message), do: {:error, {:validation_failed, %{field => [message]}}}
end
