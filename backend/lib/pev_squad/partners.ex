defmodule PevSquad.Partners do
  @moduledoc """
  Partner communities (local and vehicle-specific groups PEV Squad rides
  with) and brand partners. Staff manage them; events link to them, so each
  partner page shows the history of what we've done together.
  """

  import Ecto.Query, warn: false

  alias PevSquad.Accounts.Scope
  alias PevSquad.Events.Event
  alias PevSquad.Partners.{Logo, Partner}
  alias PevSquad.Repo

  ## Public

  @doc "Published partners of one kind, in staff order, each with `event_count`."
  def list_partners(kind) do
    Partner
    |> where(kind: ^kind, published: true)
    |> order_by([p], asc: p.position, asc: fragment("lower(?)", p.name))
    |> Repo.all()
    |> put_event_counts()
  end

  def get_public_partner!(slug), do: Repo.get_by!(Partner, slug: slug, published: true)

  @doc "Published events done with a partner, most recent first."
  def list_partner_events(%Partner{id: id}), do: PevSquad.Events.list_partner_events(id)

  defp put_event_counts(partners) do
    ids = Enum.map(partners, & &1.id)

    counts =
      from(ep in "event_partners",
        join: e in Event,
        on: e.id == ep.event_id,
        where: ep.partner_id in ^ids and e.status == :published,
        group_by: ep.partner_id,
        select: {ep.partner_id, count(ep.event_id)}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(partners, &Map.put(&1, :event_count, Map.get(counts, &1.id, 0)))
  end

  ## Staff

  def list_all_partners(%Scope{} = scope) do
    ensure_staff!(scope)

    Partner
    |> order_by([p], desc: p.kind, asc: p.position, asc: fragment("lower(?)", p.name))
    |> Repo.all()
  end

  def get_partner!(%Scope{} = scope, id) do
    ensure_staff!(scope)
    Repo.get!(Partner, id)
  end

  def change_partner(%Partner{} = partner, attrs \\ %{}), do: Partner.changeset(partner, attrs)

  @doc "`logo_source`, when given, is a path to an uploaded image."
  def create_partner(%Scope{} = scope, attrs, logo_source \\ nil) do
    ensure_staff!(scope)

    # One transaction, so an unreadable logo doesn't leave a half-saved partner.
    Repo.transact(fn ->
      %Partner{}
      |> Partner.changeset(attrs)
      |> Repo.insert()
      |> attach_logo(logo_source)
    end)
  end

  def update_partner(%Scope{} = scope, %Partner{} = partner, attrs, logo_source \\ nil) do
    ensure_staff!(scope)

    Repo.transact(fn ->
      partner
      |> Partner.changeset(attrs)
      |> Repo.update()
      |> attach_logo(logo_source)
    end)
  end

  def delete_partner(%Scope{} = scope, %Partner{} = partner) do
    ensure_staff!(scope)

    with {:ok, deleted} <- Repo.delete(partner) do
      Logo.delete(deleted.logo_path)
      {:ok, deleted}
    end
  end

  def remove_logo(%Scope{} = scope, %Partner{} = partner) do
    ensure_staff!(scope)
    Logo.delete(partner.logo_path)
    partner |> Ecto.Changeset.change(logo_path: nil) |> Repo.update()
  end

  defp attach_logo({:ok, partner}, nil), do: {:ok, partner}

  defp attach_logo({:ok, partner}, source) do
    case Logo.store(source, partner.slug) do
      {:ok, path} ->
        old = partner.logo_path

        with {:ok, updated} <- partner |> Ecto.Changeset.change(logo_path: path) |> Repo.update() do
          Logo.delete(old)
          {:ok, updated}
        end

      {:error, _reason} ->
        {:error, :bad_image}
    end
  end

  defp attach_logo(error, _source), do: error

  ## Linking events

  @doc "Partners linked to an event (published ones, unless `all: true`)."
  def list_event_partners(%Event{id: event_id}, opts \\ []) do
    from(p in Partner,
      join: ep in "event_partners",
      on: ep.partner_id == p.id,
      where: ep.event_id == ^event_id,
      # Communities first ("community" > "brand").
      order_by: [desc: p.kind, asc: fragment("lower(?)", p.name)]
    )
    |> then(fn q -> if opts[:all], do: q, else: where(q, [p], p.published) end)
    |> Repo.all()
  end

  @doc "Replaces the partners linked to an event. Staff only."
  def set_event_partners(%Scope{} = scope, %Event{id: event_id}, partner_ids) do
    ensure_staff!(scope)
    ids = partner_ids |> Enum.map(&to_integer/1) |> Enum.uniq()

    Repo.transact(fn ->
      from(ep in "event_partners", where: ep.event_id == ^event_id) |> Repo.delete_all()

      existing = from(p in Partner, where: p.id in ^ids, select: p.id) |> Repo.all()
      rows = Enum.map(existing, &%{event_id: event_id, partner_id: &1})
      {count, _} = Repo.insert_all("event_partners", rows)
      {:ok, count}
    end)
  end

  defp to_integer(id) when is_integer(id), do: id
  defp to_integer(id) when is_binary(id), do: String.to_integer(id)

  defp ensure_staff!(scope) do
    unless Scope.staff?(scope), do: raise(PevSquad.Partners.NotAuthorizedError)
  end
end

defmodule PevSquad.Partners.NotAuthorizedError do
  defexception message: "only moderators and admins can manage partners", plug_status: 403
end
