defmodule PevSquad.PartnersTest do
  use PevSquad.DataCase

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.PartnersFixtures
  import PevSquad.RidersFixtures, only: [image_fixture: 2]

  alias PevSquad.Partners

  test "lists published partners of a kind in staff order" do
    b = partner_fixture(name: "Bravo", position: 2)
    a = partner_fixture(name: "Alpha", position: 2)
    first = partner_fixture(name: "Zulu", position: 1)
    _hidden = partner_fixture(name: "Hidden", published: false)
    _brand = partner_fixture(kind: :brand, name: "Acme")

    assert Enum.map(Partners.list_partners(:community), & &1.id) == [first.id, a.id, b.id]
  end

  test "slugs are generated and social handles cleaned up" do
    p =
      partner_fixture(
        name: "Eboard Indonesia",
        instagram: "https://www.instagram.com/eboardindonesia/",
        tiktok: "@eboard.id"
      )

    assert p.slug == "eboard-indonesia"
    assert p.instagram == "eboardindonesia"
    assert p.tiktok == "eboard.id"
  end

  test "validates links" do
    assert {:error, changeset} =
             Partners.create_partner(staff_scope_fixture(), %{
               kind: :brand,
               name: "Acme",
               website: "acme.com"
             })

    assert %{website: [_]} = errors_on(changeset)
  end

  test "stores a logo as WebP, fitted not cropped" do
    partner =
      partner_fixture(name: "Wide Logo")
      |> then(&Partners.update_partner(staff_scope_fixture(), &1, %{}, image_fixture(1200, 400)))
      |> elem(1)

    assert partner.logo_path =~ ~r{^/uploads/logos/wide-logo-.+\.webp$}
    file = PevSquad.Uploads.path(String.replace_prefix(partner.logo_path, "/uploads/", ""))
    {:ok, image} = Image.open(file)
    assert {600, 200, _} = Image.shape(image)

    {:ok, _} = Partners.delete_partner(staff_scope_fixture(), partner)
    refute File.exists?(file)
  end

  test "an unreadable logo leaves nothing behind" do
    bad = Path.join(System.tmp_dir!(), "not-an-image-#{System.unique_integer()}.png")
    File.write!(bad, "nope")

    assert {:error, :bad_image} =
             Partners.create_partner(staff_scope_fixture(), %{kind: :brand, name: "Ghost"}, bad)

    assert Partners.list_partners(:brand) == []
  end

  test "events link to partners; the partner page lists them with a count" do
    staff = staff_scope_fixture()
    snoi = partner_fixture(name: "SNOI", vehicle_focus: :escooter)
    hyundai = partner_fixture(kind: :brand, name: "Hyundai", collaboration_types: [:venue])
    event = event_fixture(title: "Showroom Visit")

    _draft =
      event_fixture(status: :draft) |> tap(&Partners.set_event_partners(staff, &1, [snoi.id]))

    assert {:ok, 2} = Partners.set_event_partners(staff, event, [snoi.id, "#{hyundai.id}"])
    assert Enum.map(Partners.list_event_partners(event), & &1.name) == ["SNOI", "Hyundai"]

    # Drafts don't count toward the track record.
    assert [%{id: id}] = Partners.list_partner_events(snoi)
    assert id == event.id
    assert [%{event_count: 1}] = Partners.list_partners(:community)

    assert {:ok, 1} = Partners.set_event_partners(staff, event, [hyundai.id])
    assert Partners.list_partner_events(snoi) == []
  end

  test "members can't manage partners" do
    assert_raise PevSquad.Partners.NotAuthorizedError, fn ->
      Partners.create_partner(user_scope_fixture(), %{kind: :brand, name: "Mine"})
    end

    assert_raise PevSquad.Partners.NotAuthorizedError, fn ->
      Partners.set_event_partners(user_scope_fixture(), event_fixture(), [])
    end
  end
end
