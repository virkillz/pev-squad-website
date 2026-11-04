# Development seeds. Run with `mix run priv/repo/seeds.exs` (or `mix ecto.reset`).
# Safe to re-run: existing rows (matched by email / slug) are left alone.
#
# Creates:
#   * admin@pev-squad.org (admin) and five demo riders, all with the password
#     below, so RSVP / waitlist flows can be tried locally
#   * the real event history from the prototype (events.md / events.html)
#   * two DEMO upcoming rides with limited seats — one already full
#   * the PEV model catalog and six DEMO reviews (prototype placeholder text)
#   * two DEMO group rides hosted by demo reviewers
#   * partner communities and brand partners, linked to past events

if System.get_env("MIX_ENV") == "prod" do
  raise "priv/repo/seeds.exs creates demo accounts and content — never run it in production"
end

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

# --- Model catalog + DEMO reviews ------------------------------------------
# Reviewers and review text are the prototype's placeholder content.

alias PevSquad.Reviews.{PevModel, Review}
alias PevSquad.Riders.RiderProfile

catalog = [
  {:euc, "Kingsong", "S22 Pro"},
  {:euc, "Kingsong", "F18"},
  {:euc, "Kingsong", "S16 Pro"},
  {:euc, "Inmotion", "V13"},
  {:euc, "Begode", "Master Pro"},
  {:euc, "Leaperkim", "Sherman L"},
  {:euc, "Leaperkim", "Sherman OG"},
  {:euc, "Leaperkim", "Lynx"},
  {:euc, "Leaperkim", "Lynx S"},
  {:euc, "Leaperkim", "Patton"},
  {:euc, "Leaperkim", "Abrams"},
  {:escooter, "Dualtron", "Thunder 3"},
  {:escooter, "Kaabo", "Wolf Warrior 11"},
  {:esk8, "Acedeck", "Ares X1"},
  {:esk8, "Trampa", "Custom Build"},
  {:ebike, "Fiido", "Gorilla"}
]

models =
  Map.new(catalog, fn {type, brand, name} ->
    model =
      Repo.get_by(PevModel, brand: brand, name: name) ||
        %PevModel{approved: true, created_by_id: admin.id}
        |> PevModel.changeset(%{pev_type: type, brand: brand, name: name})
        |> Repo.insert!()

    {"#{brand} #{name}", model}
  end)

demo_reviews = [
  {"Rangga", true, "Kingsong S22 Pro", "Most planted wheel",
   "The most planted high-speed EUC we've tested this year. Suspension handles Jakarta's broken asphalt with ease — the only knock is charge time.",
   "Charge time is the one real knock. Plan long rides around it, or budget for a second charger.",
   2100, {9.4, 8.8, 9.2, 8.6, 7.4, nil}},
  {"Dinda", true, "Dualtron Thunder 3", "Brutal for the price",
   "Brutal acceleration for the price, but the stock tires are a liability in the wet. Budget for an upgrade before you take it out in rain.",
   "Stock tires in the rain.", 3400, {9.7, 8.6, 7.8, 8.0, 8.5, 7.0}},
  {"Ayu", true, "Inmotion V13", "Best first big wheel",
   "Best beginner-to-intermediate wheel we've put someone on. Forgiving pedal response, solid app, and parts are easy to source locally.",
   nil, 1800, {8.6, 7.6, 8.8, 8.7, 9.1, 9.0}},
  {"Teuku", true, "Trampa Custom Build", "Built for flat roads",
   "Dual-belt build tuned for Surabaya's flat, wide roads. VESC tuning notes included for anyone building the same setup.",
   "Not cheap, and not something to carry far.", 2600, {9.2, 8.0, 8.4, 9.5, 6.8, nil}},
  {"Bimo", false, "Begode Master Pro", "Shim the pedals first",
   "Torque is there but the pedals feel loose out of the box. Fine once shimmed, annoying that it's needed at all.",
   "Out-of-box pedal play.", 900, {8.8, 8.0, 7.2, 6.0, 7.0, 6.5}},
  {"Fajar", false, "Kaabo Wolf Warrior 11", "Heavy but planted",
   "Heavy but planted at speed. Good pick if you mostly ride flat roads and don't need to carry it up stairs.",
   "The weight.", 1500, {8.5, 8.2, 8.0, 8.1, 7.9, nil}}
]

for {name, featured?, model_name, headline, summary, the_catch, km, {pw, rg, cf, bd, vl, ap}} <-
      demo_reviews do
  user = upsert_user.("#{String.downcase(name)}@demo.pev-squad.org", :member)

  Repo.get_by(RiderProfile, user_id: user.id) ||
    %RiderProfile{
      user_id: user.id,
      is_public: true,
      featured_since: if(featured?, do: now)
    }
    |> RiderProfile.changeset(%{alias: name, city: "Jakarta", main_ride: model_name})
    |> Repo.insert!()

  model = Map.fetch!(models, model_name)

  Repo.get_by(Review, author_id: user.id, pev_model_id: model.id) ||
    %Review{
      author_id: user.id,
      status: :published,
      featured: featured?,
      published_at: now,
      moderated_by_id: admin.id
    }
    |> Review.changeset(%{
      pev_model_id: model.id,
      headline: headline,
      summary: summary,
      the_ride: summary,
      the_catch: the_catch,
      km_on_unit: km,
      score_power: pw,
      score_range: rg,
      score_comfort: cf,
      score_build: bd,
      score_value: vl,
      score_app: ap
    })
    |> Repo.insert!()
end

# --- DEMO group rides (member-hosted) -------------------------------------
# Hosted by demo reviewers, who have rider profiles by now.

for {host_name, slug, attrs} <- [
      {"rangga", "demo-cfd-senayan-cruise",
       %{
         title: "Car-Free-Day Senayan Cruise",
         kind: :ride,
         starts_at: in_days.(5, {6, 0}),
         location_name: "Senayan, Jakarta",
         meeting_point: "FX Sudirman, lobby parking",
         capacity: 12,
         description:
           "DEMO GROUP RIDE. Slow cruise around Senayan before the CFD crowd gets big, then coffee. Beginners welcome — we wait for everyone."
       }},
      {"dinda", "demo-bsd-trail-practice",
       %{
         title: "BSD Trail Practice",
         kind: :trail_ride,
         starts_at: in_days.(13, {7, 30}),
         location_name: "BSD, Tangerang",
         meeting_point: "The Breeze, east parking",
         capacity: 8,
         description:
           "DEMO GROUP RIDE. Dirt and gravel practice on the empty lots. Knobby tyres recommended, full gear required."
       }}
    ] do
  host = upsert_user.("#{host_name}@demo.pev-squad.org", :member)

  Repo.get_by(Event, slug: slug) ||
    %Event{
      slug: slug,
      category: :group_ride,
      status: :published,
      created_by_id: host.id
    }
    |> Event.group_ride_changeset(attrs)
    |> Repo.insert!()
end

# --- Partners ---------------------------------------------------------------
# Communities named by the squad; brands taken from the event history above.
# Only what we know for sure — staff fill in logos, descriptions and links.

alias PevSquad.Partners.Partner

partner_seeds = [
  {%{
     kind: :community,
     name: "REJS",
     tagline: "EUC Rider Jakarta Selatan",
     region: "Jakarta Selatan",
     vehicle_focus: :euc,
     position: 1
   }, []},
  {%{
     kind: :community,
     name: "Eastlectric",
     tagline: "Group rides around Surabaya and Malang",
     region: "Surabaya & Malang",
     position: 2
   }, ["Ngeride ke Bromo"]},
  {%{
     kind: :community,
     name: "Jogwheel",
     tagline: "Group rides in Yogyakarta",
     region: "Yogyakarta",
     position: 3
   }, []},
  {%{
     kind: :community,
     name: "SNOI",
     tagline: "Electric scooter community",
     vehicle_focus: :escooter,
     position: 4
   }, ["Ngabuburide", "Hyundai Showroom Visit"]},
  {%{
     kind: :community,
     name: "Eboard Indonesia",
     tagline: "Electric skateboard community",
     vehicle_focus: :esk8,
     instagram: "eboardindonesia",
     position: 5
   }, ["Perklindo EV Show"]},
  {%{kind: :brand, name: "Taco Bell", collaboration_types: [:food_drink, :venue], position: 1},
   ["Taco Bell Ride", "Taco Bell Ride Vol. 2"]},
  {%{kind: :brand, name: "Wheelsxtreme", collaboration_types: [:event_partner], position: 2},
   ["Taco Bell Ride"]},
  {%{kind: :brand, name: "Hyundai", collaboration_types: [:venue], position: 3},
   ["Hyundai Showroom Visit"]},
  {%{kind: :brand, name: "Rinso", collaboration_types: [:event_partner], position: 4},
   ["Rinso Promo Event"]},
  {%{kind: :brand, name: "TV One", collaboration_types: [:media], position: 5},
   ["TV One Interview"]}
]

# Free-text names that now have a partner page ("East Electric" is the old
# spelling of Eastlectric in the event history).
aliases = %{"East Electric" => "Eastlectric", "eboardindonesia" => "Eboard Indonesia"}

for {attrs, event_titles} <- partner_seeds do
  slug = Event.slugify(attrs.name, nil)

  partner =
    Repo.get_by(Partner, slug: slug) ||
      %Partner{} |> Partner.changeset(attrs) |> Repo.insert!()

  for title <- event_titles, event = Repo.get_by(Event, title: title) do
    Repo.insert_all("event_partners", [%{event_id: event.id, partner_id: partner.id}],
      on_conflict: :nothing
    )

    # Drop the linked name from the free-text list so it isn't shown twice.
    leftover =
      (event.partners || "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(Map.get(aliases, &1, &1) == partner.name))
      |> Enum.join(", ")

    event
    |> Ecto.Changeset.change(partners: if(leftover == "", do: nil, else: leftover))
    |> Repo.update!()
  end
end

IO.puts("""

Seeded. Log in at http://localhost:4000/users/log-in with:
  admin@pev-squad.org / #{password}   (admin)
  alwi@demo.pev-squad.org / #{password}  (member; also rendi, awang, kuntz, shaz)
  rangga@demo.pev-squad.org / #{password}  (Featured Rider with a published review)
""")
