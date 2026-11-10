defmodule PevSquadWeb.PrivacyLive.Index do
  @moduledoc """
  The privacy policy, for the website and the app stores (Google Play and
  the App Store both need a public URL). `#delete-account` is the account
  deletion URL that Google Play asks for.

  The policy is legal text, so each language is written out in full as
  its own template instead of going through Gettext string by string.
  Keep the two versions in step, and bump `@updated` when either changes.
  """
  use PevSquadWeb, :live_view

  # pev-squad.org has no MX record, so privacy requests go to the admin's
  # inbox. Switch to a privacy@pev-squad.org forward once one exists.
  @contact_email "virkill@gmail.com"
  @updated ~D[2026-11-10]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">{gettext("Legal")}</span>
          <span class="tag-scribble">
            {gettext("Updated %{date}", date: PevSquadWeb.Locale.strftime(@updated, "%-d %B %Y"))}
          </span>
        </div>
        <h1 class="page-title">{gettext("Privacy policy")}</h1>
      </section>

      <section class="band band-white">
        <div class="post-body" id="privacy-policy">
          <%= if @locale == "id" do %>
            <.policy_id email={@email} />
          <% else %>
            <.policy_en email={@email} />
          <% end %>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Privacy policy"))
     |> assign(
       :page_description,
       gettext(
         "What PEV Squad collects on the website and in the app, why, and how to delete it."
       )
     )
     |> assign(:email, @contact_email)
     |> assign(:updated, @updated)}
  end

  attr :email, :string, required: true

  defp policy_id(assigns) do
    ~H"""
    <p>
      PEV Squad adalah komunitas pengendara kendaraan listrik pribadi (EUC, skuter performa, papan
      luncur listrik) di Indonesia. Kebijakan ini menjelaskan data apa yang kami kumpulkan di situs
      <a href="https://pev-squad.org">pev-squad.org</a>
      dan aplikasi PEV Squad, untuk apa, dan bagaimana kamu bisa menghapusnya. Kami mengikuti
      Undang-Undang No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.
    </p>

    <h2>Data yang kami kumpulkan</h2>
    <ul>
      <li>
        <strong>Akun:</strong>
        alamat email, kata sandi (disimpan dalam bentuk hash, jika kamu membuatnya), dan pilihan bahasa.
      </li>
      <li>
        <strong>Profil rider:</strong>
        alias, nama lengkap, kota, bio, jenis dan model PEV, akun Instagram, dan foto profil.
      </li>
      <li>
        <strong>Konten yang kamu kirim:</strong>
        ulasan, foto galeri, iklan jual beli (termasuk nomor WhatsApp atau Instagram untuk dihubungi),
        group ride yang kamu buat, dan pendaftaran (RSVP) event.
      </li>
      <li>
        <strong>Keamanan:</strong>
        laporan yang kamu kirim, member yang kamu blokir, dan token sesi login.
      </li>
      <li>
        <strong>Log teknis:</strong>
        server kami mencatat alamat IP dan jenis peramban untuk keamanan dan memperbaiki gangguan.
      </li>
    </ul>
    <p>
      Kami <strong>tidak</strong>
      memakai iklan, alat analitik, atau pelacak pihak ketiga, dan tidak mengumpulkan lokasi perangkatmu.
      Aplikasi hanya meminta akses kamera dan galeri foto saat kamu memilih foto profil. Data lokasi
      (EXIF/GPS) dihapus dari setiap foto yang diunggah.
    </p>

    <h2>Untuk apa data dipakai</h2>
    <ul>
      <li>Membuat dan menjaga akunmu, termasuk mengirim tautan masuk lewat email.</li>
      <li>Menampilkan profil rider, ulasan, foto, dan iklanmu kepada pengunjung lain.</li>
      <li>Mengelola event: daftar peserta, daftar tunggu, dan pemberitahuan perubahan.</li>
      <li>Moderasi dan keamanan komunitas: meninjau laporan dan mencegah penyalahgunaan.</li>
    </ul>
    <p>Kami tidak menjual data pribadimu dan tidak memakainya untuk iklan.</p>

    <h2>Apa yang terlihat publik</h2>
    <p>
      Profil rider hanya tampil di situs jika kamu menyetujuinya. Yang tampil adalah alias, kota, PEV,
      bio, foto, dan Instagram. Nama lengkap dan email-mu tidak pernah ditampilkan. Ulasan, foto galeri,
      dan iklan yang sudah disetujui terlihat oleh semua orang. Kontak penjual di iklan hanya terlihat
      oleh member yang sudah masuk.
    </p>

    <h2>Pihak yang memproses data</h2>
    <ul>
      <li>
        <strong>DigitalOcean</strong> (server di Singapura) menyimpan situs, database, dan foto.
      </li>
      <li>
        <strong>Brevo</strong> mengirim email kami, seperti tautan masuk dan pemberitahuan event.
      </li>
      <li>
        <strong>Expo</strong>
        mengirimkan pembaruan aplikasi; jika notifikasi push aktif, token perangkatmu juga melewati Expo.
      </li>
    </ul>
    <p>
      Karena server berada di luar Indonesia, datamu disimpan dan diproses di Singapura dan di negara
      penyedia di atas.
    </p>

    <h2>Berapa lama data disimpan</h2>
    <p>
      Data disimpan selama akunmu aktif. Cadangan database harian disimpan 7 hari, jadi data yang
      dihapus akan hilang sepenuhnya dari cadangan dalam 7 hari. Log server disimpan dalam waktu singkat
      untuk keperluan keamanan.
    </p>

    <h2 id="delete-account">Menghapus akun dan data</h2>
    <p>Kamu bisa menghapus akunmu kapan saja:</p>
    <ul>
      <li>
        <strong>Di aplikasi:</strong>
        buka menu avatar → <strong>Pengaturan</strong>
        → <strong>Hapus akun</strong>. Kamu perlu masuk ulang untuk konfirmasi.
      </li>
      <li>
        <strong>Lewat email:</strong>
        kirim permintaan ke <a href={"mailto:" <> @email}>{@email}</a>
        dari alamat email akunmu. Kami memprosesnya dalam 14 hari.
      </li>
    </ul>
    <p>
      Menghapus akun akan menghapus email, profil rider, foto profil, ulasan, foto galeri, iklan, group
      ride yang kamu buat, RSVP, blokir, dan sesi login. Pendaftaranmu di event mendatang dibatalkan.
      Profil rider yang dibuat oleh pengurus dari data pendaftaran lama dan diklaim olehmu juga dihapus.
      Laporan yang kamu kirim tentang konten orang lain bisa kami simpan untuk keperluan moderasi.
    </p>

    <h2>Hak kamu</h2>
    <p>
      Kamu bisa melihat dan mengubah profilmu di aplikasi atau situs kapan saja. Kamu juga bisa meminta
      salinan datamu, koreksi, atau penghapusan lewat <a href={"mailto:" <> @email}>{@email}</a>. Kamu bisa menarik persetujuan tampil di situs
      kapan saja dari pengaturan profil.
    </p>

    <h2>Anak-anak</h2>
    <p>
      Layanan ini ditujukan untuk usia 18 tahun ke atas. Kami tidak sengaja mengumpulkan data anak di
      bawah umur. Jika kamu orang tua dan mengetahui anakmu mendaftar, hubungi kami dan kami akan
      menghapusnya.
    </p>

    <h2>Perubahan kebijakan</h2>
    <p>
      Jika kebijakan ini berubah, kami memperbarui tanggal di atas. Untuk perubahan penting, kami
      memberi tahu member lewat email atau aplikasi.
    </p>

    <h2>Kontak</h2>
    <p>
      Pertanyaan tentang privasi: <a href={"mailto:" <> @email}>{@email}</a>.
    </p>
    """
  end

  attr :email, :string, required: true

  defp policy_en(assigns) do
    ~H"""
    <p>
      PEV Squad is a community of personal electric vehicle riders (EUCs, performance scooters,
      electric skateboards) in Indonesia. This policy explains what we collect on
      <a href="https://pev-squad.org">pev-squad.org</a>
      and in the PEV Squad app, why, and how you can delete it. We follow Indonesia's Personal Data
      Protection Law (Law No. 27 of 2022).
    </p>

    <h2>What we collect</h2>
    <ul>
      <li>
        <strong>Account:</strong>
        your email address, your password (stored as a hash, if you set one) and your language.
      </li>
      <li>
        <strong>Rider profile:</strong>
        alias, full name, city, bio, PEV type and model, Instagram handle and profile photo.
      </li>
      <li>
        <strong>What you post:</strong>
        reviews, gallery photos, for-sale listings (including the WhatsApp number or Instagram buyers
        contact you on), group rides you host, and event RSVPs.
      </li>
      <li>
        <strong>Safety:</strong> reports you file, members you block, and login session tokens.
      </li>
      <li>
        <strong>Technical logs:</strong>
        our server records IP addresses and browser type, for security and to fix problems.
      </li>
    </ul>
    <p>
      We do <strong>not</strong>
      use ads, analytics or third-party trackers, and we don't collect your device's location. The app
      asks for the camera and photo library only when you choose a profile photo. Location data
      (EXIF/GPS) is removed from every uploaded photo.
    </p>

    <h2>How we use it</h2>
    <ul>
      <li>To create and run your account, including emailing you login links.</li>
      <li>To show your rider profile, reviews, photos and listings to other visitors.</li>
      <li>To run events: rider lists, waitlists and notices when something changes.</li>
      <li>To moderate the community and keep it safe: reviewing reports and stopping abuse.</li>
    </ul>
    <p>We don't sell your personal data or use it for advertising.</p>

    <h2>What is public</h2>
    <p>
      Your rider profile appears on the site only if you agree to it. It shows your alias, city, PEVs,
      bio, photo and Instagram. Your full name and email are never shown. Approved reviews, gallery
      photos and listings are visible to everyone. A seller's contact details on a listing are shown
      only to logged-in members.
    </p>

    <h2>Who processes your data</h2>
    <ul>
      <li>
        <strong>DigitalOcean</strong> (servers in Singapore) hosts the site, database and photos.
      </li>
      <li><strong>Brevo</strong> sends our emails, such as login links and event notices.</li>
      <li>
        <strong>Expo</strong>
        delivers app updates; if push notifications are on, your device token also passes through Expo.
      </li>
    </ul>
    <p>
      Because our servers are outside Indonesia, your data is stored and processed in Singapore and in
      the countries of the providers above.
    </p>

    <h2>How long we keep it</h2>
    <p>
      We keep your data while your account is active. Daily database backups are kept for 7 days, so
      deleted data is gone from the backups within 7 days. Server logs are kept briefly, for security.
    </p>

    <h2 id="delete-account">Deleting your account and data</h2>
    <p>You can delete your account at any time:</p>
    <ul>
      <li>
        <strong>In the app:</strong>
        open the avatar menu → <strong>Settings</strong>
        → <strong>Delete account</strong>. You'll be asked to log in again to confirm.
      </li>
      <li>
        <strong>By email:</strong>
        send a request to <a href={"mailto:" <> @email}>{@email}</a>
        from your account's email address. We handle it within 14 days.
      </li>
    </ul>
    <p>
      Deleting your account removes your email, rider profile, profile photo, reviews, gallery photos,
      listings, group rides you host, RSVPs, blocks and login sessions. Your places at upcoming events
      are cancelled. A rider profile that staff created from the old sign-up sheet and that you claimed
      is deleted too. Reports you filed about other people's content may be kept for moderation.
    </p>

    <h2>Your rights</h2>
    <p>
      You can see and change your profile in the app or on the site at any time. You can also ask for a
      copy of your data, a correction or deletion at <a href={"mailto:" <> @email}>{@email}</a>. You can withdraw consent to appear on the site at
      any time from your profile settings.
    </p>

    <h2>Children</h2>
    <p>
      The service is meant for people aged 18 and over. We don't knowingly collect data from minors. If
      you're a parent and find your child has signed up, contact us and we'll delete the account.
    </p>

    <h2>Changes</h2>
    <p>
      When this policy changes, we update the date above. For important changes, we tell members by
      email or in the app.
    </p>

    <h2>Contact</h2>
    <p>
      Privacy questions: <a href={"mailto:" <> @email}>{@email}</a>.
    </p>
    """
  end
end
