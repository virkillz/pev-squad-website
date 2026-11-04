# Development seeds. Run with `mix run priv/repo/seeds.exs` (or `mix ecto.reset`).
# Safe to re-run: existing rows (matched by email / slug) are left alone.
#
# Creates:
#   * admin@pev-squad.org (admin) and five demo riders, all with the password
#     below, so RSVP / waitlist flows can be tried locally
#   * the real event history from the prototype (events.md / events.html)
#   * two DEMO upcoming rides with limited seats — one already full

import Ecto.Query

alias PevSquad.Repo
alias PevSquad.Accounts.User
alias PevSquad.Events.{Event, Rsvp}

password = "ride-fast-ride-far"
now = DateTime.utc_now(:second)

upsert_user = fn email, role ->
  Repo.get_by(User, email: email) ||
    %User{role: role, confirmed_at: now}
    |> User.email_changeset(%{email: email})
    |> User.password_changeset(%{password: password})
    |> Repo.insert!()
end

admin = upsert_user.("admin@pev-squad.org", :admin)

riders =
  for name <- ~w(alwi rendi awang kuntz shaz) do
    upsert_user.("#{name}@demo.pev-squad.org", :member)
  end

# Local wall-clock time in Jakarta -> UTC.
wib = fn {y, m, d}, {h, min} ->
  NaiveDateTime.new!(y, m, d, h, min, 0)
  |> DateTime.from_naive!("Asia/Jakarta")
  |> DateTime.shift_zone!("Etc/UTC")
end

upsert_event = fn attrs ->
  slug = attrs[:slug] || Event.slugify(attrs.title, attrs.starts_at)

  Repo.get_by(Event, slug: slug) ||
    %Event{created_by_id: admin.id}
    |> Event.changeset(Map.merge(%{status: :published, slug: slug}, attrs))
    |> Repo.insert!()
end

past = [
  {"Dieng Tour", :tour, :organizer, nil, {2023, 10, 12}, {2023, 10, 14}, "Dieng",
   "Three days in the Dieng highlands — the trip that set the template for every squad getaway since."},
  {"Taco Bell Ride", :ride, :organizer, "Taco Bell, Wheelsxtreme", {2024, 10, 28}, nil,
   "Taco Bell Senopati",
   "40 riders rolled into Taco Bell Senopati — EUC, e-bike, scooter, esk8 and big bikes all in one pack. EUC coaching clinics ran on the side, supported by Taco Bell and Wheelsxtreme."},
  {"Taco Bell Ride Vol. 2", :ride, :organizer, "Taco Bell", {2024, 12, 23}, nil, nil,
   "Second run of the Taco Bell ride, back by demand after October's turnout."},
  {"Anaconda", :trail_ride, :collaborator, "After Rain", {2025, 2, 13}, nil, "Bogor",
   "Run with After Rain in Bogor, backed by Teh Pucuk Harum. The worst trail we've tackled so far — sliding rock, dirt and deep mud the whole way."},
  {"Ngabuburide", :ride, :organizer, "ALVA, NERO, SNOI", {2025, 2, 28}, nil, "ALVA SCBD Jakarta",
   "Ramadan-season ride timed to end at buka puasa, hosted at ALVA SCBD Jakarta with ALVA, NERO and SNOI."},
  {"Perklindo EV Show", :exhibition, :collaborator, "eboardindonesia", {2025, 5, 3}, nil, nil,
   "Invited alongside eboardindonesia to represent the PEV community at the electric vehicle exhibition."},
  {"Menyusuri Punggung Jawa", :expedition, :collaborator, nil, {2025, 8, 26}, {2025, 8, 30},
   "Purwokerto → Banyuwangi",
   "Five days, roughly 1,000 km, Purwokerto to Banyuwangi along the spine of Java. Alwi, Rendi, Awang and Kuntz made the whole distance on wheels."},
  {"Mararia", :race, :organizer, "Buttons, Aruna Coffee, RS BSH", {2025, 10, 18}, nil, "Bogor",
   "Cannonball-style race in Bogor with exactly two rules: first to arrive wins, and don't die. Fuelled by Buttons and Aruna Coffee, with RS BSH standing by as medical partner."},
  {"Hell on Wheels", :night_ride, :collaborator, "Le Victoria", {2025, 10, 30}, nil, nil,
   "Halloween night ride with Le Victoria. Costumes mandatory, helmets still more mandatory."},
  {"Coffee Rave", :night_ride, :collaborator, "Le Victoria", {2025, 11, 19}, nil, nil,
   "Late ride with Le Victoria. Caffeine, sound system, and a slow roll home."},
  {"Cisadon Expedition", :trail_ride, :organizer, nil, {2025, 12, 3}, nil, "Cisadon, Bogor",
   "The famous Cisadon track in Bogor — dirt, rock and mud, start to finish. Everyone came back filthy, which is the point."},
  {"TV One Interview", :media, :collaborator, "TV One", {2025, 12, 13}, nil, "TMII Jakarta",
   "Filmed at TMII Jakarta. A chance to explain what personal electric vehicles actually are to an audience that mostly meets us in traffic."},
  {"Rinso Promo Event", :brand_activation, :collaborator, "Rinso", {2025, 12, 22}, nil,
   "CFD Jakarta",
   "Several of the squad's female EUC riders helped launch a new Rinso product during Car Free Day Jakarta."},
  {"Nusantara Mengaspal", :collab, :collaborator, "Team Sharing Beroda, BKT Runner",
   {2026, 1, 31}, nil, "TMII Jakarta",
   "Running and games at TMII Jakarta, organized by Team Sharing Beroda with BKT Runner. We turned up on wheels to support."},
  {"Ngeride ke Bromo", :getaway, :organizer, "East Electric", {2026, 4, 18}, {2026, 4, 19},
   "Bromo, Malang",
   "Overnight run to Bromo, Malang, co-organized with East Electric. Cold air, thin light, and the kind of view that justifies the charging logistics."},
  {"Hyundai Showroom Visit", :brand_invite, :collaborator, "Hyundai, SNOI", {2026, 4, 25}, nil,
   "Hyundai, Spark Mall Jakarta",
   "Hyundai invited the squad — alongside SNOI — to their Spark Mall Jakarta showroom. Electric wheels parked next to electric cars."},
  {"Vespa GT Collab Ride", :collab_ride, :collaborator, "2 Wheels One Spirit", {2026, 5, 2}, nil,
   "Jakarta",
   "Joint ride through Jakarta with the Vespa community under the 2 Wheels One Spirit banner. Different machines, same road, no ego."},
  {"Bogorun 2026", :marshal, :collaborator, nil, {2026, 5, 10}, nil, "Sentul, Bogor",
   "Sentul, Bogor. The squad ran EUC marshal duty for the lead pack, pacing the potential winners and keeping the course clear ahead of them."},
  {"Ngeride ke Jogja", :getaway, :organizer, nil, {2026, 6, 20}, {2026, 6, 21}, "Jogja",
   "Two-day squad getaway to Jogja. Ride in, eat well, sleep badly, ride home — the format that keeps working."},
  {"Lokaria", :collab, :collaborator, "Lokaria", {2026, 7, 25}, nil, "GBK Jakarta",
   "Invited by the Lokaria organizers to GBK Jakarta. We're running an open booth to introduce the squad, with DJs on site and a mini PEV drag race for anyone who wants to find out what their wheel actually does."},
  {"Dagelan", :collab, :collaborator, "Dagelan", {2026, 8, 1}, nil, "Jakarta",
   "Joining Dagelan in Jakarta as a community collaborator."}
]

for {title, kind, role, partners, start_date, end_date, location, description} <- past do
  upsert_event.(%{
    title: title,
    kind: kind,
    role: role,
    partners: partners,
    starts_at: wib.(start_date, {8, 0}),
    ends_at: end_date && wib.(end_date, {18, 0}),
    location_name: location,
    description: description
  })
end

# --- DEMO upcoming rides (not real events) --------------------------------
# Dated relative to today so they always show as upcoming.

in_days = fn days, {h, m} ->
  date = Date.add(DateTime.to_date(DateTime.shift_zone!(now, "Asia/Jakarta")), days)
  wib.({date.year, date.month, date.day}, {h, m})
end

night_loop =
  upsert_event.(%{
    slug: "demo-sudirman-thamrin-night-loop",
    title: "Sudirman–Thamrin Night Loop",
    kind: :night_ride,
    role: :organizer,
    starts_at: in_days.(10, {20, 0}),
    ends_at: in_days.(10, {23, 0}),
    location_name: "Jakarta",
    meeting_point: "Bundaran HI, north side",
    capacity: 30,
    description:
      "DEMO EVENT. Easy-pace night loop down Sudirman and Thamrin and back. Lights on, helmets on, no racing in the pack.\n\nRoll-out 20:15 sharp."
  })

garut =
  upsert_event.(%{
    slug: "demo-ngeride-ke-garut",
    title: "Ngeride ke Garut",
    kind: :getaway,
    role: :organizer,
    partners: "East Electric",
    starts_at: in_days.(24, {6, 0}),
    ends_at: in_days.(25, {17, 0}),
    location_name: "Garut, Jawa Barat",
    meeting_point: "Rest area KM 57, Tol Jakarta–Cikampek",
    capacity: 4,
    rsvp_deadline: in_days.(20, {23, 59}),
    description:
      "DEMO EVENT. Two-day getaway to Garut with a support car for chargers and luggage. Seats are limited by the support car — first come, first served.\n\nFull armour required. Minimum 100 km range on a single charge."
  })

# Fill the Garut ride: four going, one on the waitlist (in RSVP order).
if Repo.aggregate(where(Rsvp, event_id: ^garut.id), :count) == 0 do
  riders
  |> Enum.with_index()
  |> Enum.each(fn {rider, i} ->
    Repo.insert!(%Rsvp{
      event_id: garut.id,
      user_id: rider.id,
      status: if(i < garut.capacity, do: :going, else: :waitlist),
      inserted_at: DateTime.add(DateTime.utc_now(), i, :second),
      updated_at: DateTime.utc_now()
    })
  end)
end

if Repo.aggregate(where(Rsvp, event_id: ^night_loop.id), :count) == 0 do
  for rider <- Enum.take(riders, 3) do
    Repo.insert!(%Rsvp{event_id: night_loop.id, user_id: rider.id, status: :going})
  end
end

IO.puts("""

Seeded. Log in at http://localhost:4000/users/log-in with:
  admin@pev-squad.org / #{password}   (admin)
  alwi@demo.pev-squad.org / #{password}  (member; also rendi, awang, kuntz, shaz)
""")
