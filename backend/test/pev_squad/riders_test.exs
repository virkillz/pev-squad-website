defmodule PevSquad.RidersTest do
  use PevSquad.DataCase

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.RidersFixtures
  import PevSquad.PartnersFixtures

  alias PevSquad.Riders
  alias PevSquad.Riders.{MemberImport, RiderProfile}

  describe "public listing" do
    test "only shows riders who agreed to be listed, filterable by type" do
      euc = rider_fixture(alias: "Wynn")
      esk8 = rider_fixture(alias: "Ben", primary_pev_type: :esk8)
      _hidden = rider_fixture(alias: "Shy", is_public: false)

      assert Enum.map(Riders.list_public_riders(), & &1.id) |> Enum.sort() ==
               Enum.sort([euc.id, esk8.id])

      assert [%{id: id}] = Riders.list_public_riders(type: :esk8)
      assert id == esk8.id
      assert_raise Ecto.NoResultsError, fn -> Riders.get_public_rider!("shy") end
    end

    test "paginates, keeping filters and clamping past the last page" do
      riders =
        for i <- 1..11, do: rider_fixture(alias: "Rider #{String.pad_leading("#{i}", 2, "0")}")

      _esk8 = rider_fixture(alias: "Zed", primary_pev_type: :esk8)

      page1 = Riders.paginate_public_riders(type: :euc, per_page: 9)
      assert %{page: 1, total: 11, total_pages: 2} = page1
      assert length(page1.entries) == 9

      page2 = Riders.paginate_public_riders(type: :euc, per_page: 9, page: 2)
      assert length(page2.entries) == 2

      assert Enum.map(page1.entries ++ page2.entries, & &1.id) == Enum.map(riders, & &1.id)

      assert %{page: 2} = Riders.paginate_public_riders(type: :euc, per_page: 9, page: 99)
      assert %{page: 1, total_pages: 1, entries: []} = Riders.paginate_public_riders(type: :ebike)
    end

    test "stats count riders and distinct cities" do
      rider_fixture(city: "Jakarta")
      rider_fixture(city: "jakarta")
      rider_fixture(city: "Malang")
      rider_fixture(city: "Bogor", is_public: false)

      assert Riders.stats() == %{riders: 3, cities: 2}
    end
  end

  describe "save_my_profile/3" do
    test "creates then updates the member's own profile" do
      scope = user_scope_fixture()

      assert {:ok, profile} =
               Riders.save_my_profile(scope, %{"alias" => "Si Ganteng", "is_public" => "true"})

      assert profile.slug == "si-ganteng"
      assert profile.user_id == scope.user.id

      assert {:ok, updated} = Riders.save_my_profile(scope, %{"city" => "Bogor"})
      assert updated.id == profile.id
      assert updated.city == "Bogor"
    end

    test "aliases are unique regardless of case" do
      rider_fixture(alias: "Wynn")

      assert {:error, changeset} =
               Riders.save_my_profile(user_scope_fixture(), %{"alias" => "wynn"})

      assert "is already taken by another rider" in errors_on(changeset).alias
    end

    test "normalises instagram links" do
      {:ok, p} =
        Riders.save_my_profile(user_scope_fixture(), %{
          "alias" => "Ig",
          "instagram" => "https://www.instagram.com/pevsquad/"
        })

      assert p.instagram == "pevsquad"
    end

    test "stores the photo as a 4:5 WebP and replaces the old one" do
      scope = user_scope_fixture()

      {:ok, first} = Riders.save_my_profile(scope, %{"alias" => "Photo Guy"}, image_fixture())
      assert first.avatar_path =~ ~r{^/uploads/avatars/photo-guy-.+\.webp$}

      stored = PevSquad.Uploads.path(String.trim_leading(first.avatar_path, "/uploads/"))
      {:ok, image} = Image.open(stored)
      assert {Image.width(image), Image.height(image)} == {800, 1000}

      {:ok, second} = Riders.save_my_profile(scope, %{}, image_fixture())
      refute second.avatar_path == first.avatar_path
      refute File.exists?(stored)
    end
  end

  describe "staff" do
    test "link_to_member/3 lets a registered member claim an imported profile" do
      staff = staff_scope_fixture()
      rider = rider_fixture()
      member = user_fixture()

      assert {:error, :no_such_user} = Riders.link_to_member(staff, rider, "nobody@example.com")
      assert {:ok, linked} = Riders.link_to_member(staff, rider, member.email)
      assert linked.user_id == member.id
      assert {:error, :already_claimed} = Riders.link_to_member(staff, linked, member.email)

      other = rider_fixture()
      assert {:error, :member_has_profile} = Riders.link_to_member(staff, other, member.email)
    end

    test "members are refused" do
      assert_raise PevSquad.Riders.NotAuthorizedError, fn ->
        Riders.list_all_riders(user_scope_fixture())
      end
    end
  end

  describe "MemberImport" do
    setup do
      dir = Path.join(System.tmp_dir!(), "pev-import-#{System.unique_integer([:positive])}")
      File.mkdir_p!(Path.join(dir, "photos"))
      File.cp!(image_fixture(), Path.join(dir, "photos/siganteng.png"))

      File.write!(Path.join(dir, "members.csv"), """
      ﻿Timestamp,Nama,Alias (yang akan dicantumkan di website),PEV Utama,Model PEV yang dipakai (ie. Veteran Sherman L),Kota Domisili,Bio (bakal ditulis ulang pakai AI),Foto,Bersedia dicantumkan di website?
      2026/01/01,Budi Santoso,Si Ganteng,EUC,Veteran Lynx,Kota Bogor,"Rider paling ganteng, katanya",,Ya
      2026/01/02,Andi,Ben Esk8,Eboard,Acedeck Ares X1,Jakarta,Shred,,Tidak
      2026/01/03,Andi,Ben Esk8,Eboard,Acedeck Ares X1,Jakarta,Duplicate row,,Ya
      """)

      %{dir: dir}
    end

    test "imports consenting riders publicly, others hidden, with photos", %{dir: dir} do
      results =
        MemberImport.run(Path.join(dir, "members.csv"), photos: Path.join(dir, "photos"))

      assert [
               {:imported, "Si Ganteng", "with photo"},
               {:imported, "Ben Esk8", "no photo"},
               {:skipped, "Ben Esk8", _}
             ] = results

      ganteng = Repo.get_by!(RiderProfile, alias: "Si Ganteng")
      assert ganteng.is_public
      assert ganteng.full_name == "Budi Santoso"
      assert ganteng.bio == "Rider paling ganteng, katanya"
      assert ganteng.main_ride == "Veteran Lynx"
      assert ganteng.source == :import
      assert ganteng.avatar_path
      assert is_nil(ganteng.user_id)

      ben = Repo.get_by!(RiderProfile, alias: "Ben Esk8")
      refute ben.is_public
      assert ben.primary_pev_type == :esk8
      assert ben.bio == "Shred"
    end
  end

  describe "status, hiding and deleting" do
    test "inactive riders stay listed, after active ones" do
      staff = staff_scope_fixture()
      zed = rider_fixture(alias: "Zed")
      amy = rider_fixture(alias: "Amy")

      {:ok, _} = Riders.update_rider(staff, amy, %{status: :inactive})

      assert ["Zed", "Amy"] = Enum.map(Riders.list_public_riders(), & &1.alias)
      assert Riders.get_public_rider!(amy.slug).status == :inactive
      assert Riders.stats().riders == 2
      assert zed.status == :active
    end

    test "a ban needs a public statement, is dated, and leaves the roster but not the page" do
      staff = staff_scope_fixture()
      rider = rider_fixture(alias: "Outlaw")
      rejs = partner_fixture()
      {:ok, _} = Riders.set_communities(staff, rider, [rejs.id])

      assert {:error, changeset} = Riders.update_rider(staff, rider, %{status: :banned})
      assert "write the public statement for the ban" in errors_on(changeset).ban_reason

      {:ok, banned} =
        Riders.update_rider(staff, rider, %{
          status: :banned,
          ban_reason: "Rode drunk at an event.",
          is_public: false
        })

      assert banned.banned_at
      assert Riders.list_public_riders() == []
      assert Riders.list_community_riders(rejs) == []
      assert Riders.stats().riders == 0
      assert %{ban_reason: "Rode drunk at an event."} = Riders.get_public_rider!(banned.slug)

      {:ok, lifted} = Riders.update_rider(staff, banned, %{status: :active, is_public: true})
      assert is_nil(lifted.ban_reason) and is_nil(lifted.banned_at)
      assert [_] = Riders.list_public_riders()
    end

    test "hidden by staff overrides everything, including a ban page" do
      staff = staff_scope_fixture()
      rider = rider_fixture()

      {:ok, hidden} = Riders.update_rider(staff, rider, %{hidden_by_staff: true})
      assert Riders.list_public_riders() == []
      assert_raise Ecto.NoResultsError, fn -> Riders.get_public_rider!(rider.slug) end

      {:ok, _} = Riders.update_rider(staff, hidden, %{status: :banned, ban_reason: "Fraud."})
      assert_raise Ecto.NoResultsError, fn -> Riders.get_public_rider!(rider.slug) end
    end

    test "members can't change their own status or hiding, and can't edit once banned" do
      member = user_scope_fixture()

      {:ok, own} =
        Riders.save_my_profile(member, %{
          alias: "Selfie",
          is_public: true,
          status: :banned,
          ban_reason: "x",
          hidden_by_staff: true
        })

      assert own.status == :active
      refute own.hidden_by_staff

      {:ok, _} =
        Riders.update_rider(staff_scope_fixture(), own, %{status: :banned, ban_reason: "Theft."})

      assert {:error, :banned} = Riders.save_my_profile(member, %{bio: "I'm innocent"})
      assert Riders.get_my_profile(member).bio == nil
    end

    test "deleting removes the profile and photo but keeps the member" do
      staff = staff_scope_fixture()
      member = user_scope_fixture()
      {:ok, rider} = Riders.save_my_profile(member, %{alias: "Gone"}, image_fixture())
      photo = PevSquad.Uploads.path(String.replace_prefix(rider.avatar_path, "/uploads/", ""))
      assert File.exists?(photo)

      assert_raise PevSquad.Riders.NotAuthorizedError, fn ->
        Riders.delete_rider(member, rider)
      end

      {:ok, _} = Riders.delete_rider(staff, rider)
      refute Repo.get(RiderProfile, rider.id)
      refute File.exists?(photo)
      assert Repo.get(PevSquad.Accounts.User, member.user.id)
      assert Riders.get_my_profile(member) == nil
    end
  end

  describe "staff-created riders" do
    test "staff add an unclaimed rider, with a photo" do
      staff = staff_scope_fixture()

      assert {:ok, rider} =
               Riders.create_rider(
                 staff,
                 %{alias: "Coach Inno", city: "Jakarta", is_public: true},
                 image_fixture()
               )

      assert rider.source == :staff
      assert rider.slug == "coach-inno"
      assert is_nil(rider.user_id)
      assert rider.avatar_path
      assert Riders.get_public_rider!("coach-inno")
    end

    test "an unreadable photo saves nothing" do
      staff = staff_scope_fixture()
      bad = Path.join(System.tmp_dir!(), "not-an-image-#{System.unique_integer([:positive])}.jpg")
      File.write!(bad, "nope")

      assert {:error, changeset} = Riders.create_rider(staff, %{alias: "Ghost"}, bad)
      assert {"couldn't read" <> _, _} = changeset.errors[:avatar_path]
      refute Repo.get_by(RiderProfile, alias: "Ghost")
    end

    test "members can't" do
      assert_raise PevSquad.Riders.NotAuthorizedError, fn ->
        Riders.create_rider(user_scope_fixture(), %{alias: "Sneaky"})
      end
    end
  end

  describe "partner communities" do
    test "staff set them; public pages show published communities in order" do
      staff = staff_scope_fixture()
      rider = rider_fixture(alias: "Wynn")
      rejs = partner_fixture(name: "REJS")
      snoi = partner_fixture(name: "SNOI")
      hidden = partner_fixture(name: "Hidden Crew", published: false)
      brand = partner_fixture(kind: :brand, name: "Hyundai")

      assert {:ok, 3} = Riders.set_communities(staff, rider, [snoi.id, "#{rejs.id}", hidden.id])
      assert Riders.community_ids(staff, rider) == [snoi.id, rejs.id, hidden.id]

      assert ["SNOI", "REJS"] =
               Enum.map(Riders.get_public_rider!(rider.slug).communities, & &1.name)

      assert [%{communities: [_, _]}] = Riders.list_public_riders()
      assert [%{alias: "Wynn"}] = Riders.list_community_riders(rejs)
      assert [] = Riders.list_community_riders(partner_fixture())

      # Brands are ignored; replacing clears the old ones.
      assert {:ok, 1} = Riders.set_communities(staff, rider, [brand.id, rejs.id])
      assert Riders.community_ids(staff, rider) == [rejs.id]
    end

    test "at most three" do
      staff = staff_scope_fixture()
      rider = rider_fixture()
      ids = for _ <- 1..4, do: partner_fixture().id

      assert {:error, :too_many} = Riders.set_communities(staff, rider, ids)
      assert Riders.community_ids(staff, rider) == []
    end

    test "members can't set them, not even on their own profile" do
      member = user_scope_fixture()

      {:ok, own} =
        Riders.save_my_profile(member, %{alias: "Selfie", is_public: true, communities: [1]})

      partner = partner_fixture()

      assert_raise PevSquad.Riders.NotAuthorizedError, fn ->
        Riders.set_communities(member, own, [partner.id])
      end

      assert Riders.get_public_rider!(own.slug).communities == []
    end
  end
end
