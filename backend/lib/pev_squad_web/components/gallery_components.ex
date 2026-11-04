defmodule PevSquadWeb.GalleryComponents do
  @moduledoc "Photo tiles, album headers and the lightbox, matching the prototype gallery."
  use PevSquadWeb, :html

  alias PevSquad.Gallery.{Album, Photo}

  def pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  def credit(%Photo{uploader_profile: %{alias: alias_name}}), do: "Shot by #{alias_name}"
  def credit(_photo), do: nil

  attr :album, Album, required: true
  attr :number, :integer, required: true
  attr :link, :boolean, default: false

  def album_head(assigns) do
    ~H"""
    <div class="section-head">
      <div>
        <span class="eyebrow">
          Album {pad(@number)}{if @album.subtitle, do: " · #{@album.subtitle}"}
        </span>
        <h2 class="section-title">
          <.link :if={@link} navigate={~p"/gallery/#{@album.slug}"} style="text-decoration:none;">
            {@album.title}
          </.link>
          <span :if={!@link}>{@album.title}</span>
        </h2>
      </div>
      <span class="sticker">{pad(@album.photo_count)} Frames</span>
    </div>
    """
  end

  attr :photo, Photo, required: true
  attr :number, :integer, required: true
  attr :album, Album, required: true

  def photo_tile(assigns) do
    ~H"""
    <a
      class={["photo-tile", @photo.tile == :big && "t-big", @photo.tile == :wide && "t-wide"]}
      href={@photo.large_path}
      data-report={~p"/report/photo/#{@photo.id}"}
      data-title={@photo.title}
      data-desc={@photo.caption}
      data-meta={
        [@album.title, @photo.meta, credit(@photo)] |> Enum.reject(&is_nil/1) |> Enum.join(" // ")
      }
    >
      <span class="photo-num">{pad(@number)}</span>
      <img
        src={@photo.thumb_path}
        alt={@photo.alt || @photo.title || @album.title}
        loading="lazy"
        decoding="async"
      />
      <span :if={@photo.title} class="photo-cap">
        <span class="photo-cap-title">{@photo.title}</span>
        <span :if={@photo.meta} class="photo-cap-meta">{@photo.meta}</span>
      </span>
    </a>
    """
  end

  def lightbox(assigns) do
    ~H"""
    <div
      class="lightbox"
      id="lightbox"
      hidden
      role="dialog"
      aria-modal="true"
      aria-label="Photo viewer"
      phx-update="ignore"
    >
      <div class="lb-bar">
        <span>The Archive // PEV Squad</span>
        <span class="lb-count">01 / 01</span>
        <button type="button" class="lb-close">Close ✕</button>
      </div>
      <div class="lb-stage">
        <button type="button" class="lb-nav lb-prev" aria-label="Previous photo">←</button>
        <img class="lb-img" src="" alt="" />
        <button type="button" class="lb-nav lb-next" aria-label="Next photo">→</button>
      </div>
      <div class="lb-foot">
        <h2 class="lb-title"></h2>
        <p class="lb-desc"></p>
        <div class="lb-meta"></div>
        <a class="lb-report" href="#">Report this photo</a>
      </div>
    </div>
    """
  end

  @doc """
  Full-width carousel of featured photos for the home page. Slides scroll
  natively (swipe, trackpad, keyboard); the Carousel hook adds the
  buttons, counter and a gentle autoplay.
  """
  attr :photos, :list, required: true

  def featured_carousel(assigns) do
    ~H"""
    <section
      class="carousel"
      id="featured-carousel"
      phx-hook="Carousel"
      aria-roledescription="carousel"
      aria-label="Featured photos"
    >
      <div class="carousel-track" tabindex="0">
        <figure
          :for={{photo, i} <- Enum.with_index(@photos, 1)}
          class="carousel-slide"
          aria-roledescription="slide"
          aria-label={"#{i} of #{length(@photos)}"}
        >
          <img
            src={photo.large_path}
            alt={photo.alt || photo.title || photo.album.title}
            loading={if i == 1, do: "eager", else: "lazy"}
          />
          <figcaption class="carousel-caption">
            <.link navigate={~p"/gallery/#{photo.album.slug}"} class="carousel-album">
              {photo.album.title} ≫
            </.link>
            <span :if={photo.title} class="carousel-title">{photo.title}</span>
            <span :if={photo.meta || credit(photo)} class="carousel-meta">
              {[photo.meta, credit(photo)] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")}
            </span>
          </figcaption>
        </figure>
      </div>
      <div :if={length(@photos) > 1} class="carousel-controls">
        <button type="button" class="carousel-btn" data-carousel="prev" aria-label="Previous photo">
          ←
        </button>
        <span class="carousel-count" aria-live="polite">
          <b data-carousel="current">01</b> / {pad(length(@photos))}
        </span>
        <button type="button" class="carousel-btn" data-carousel="next" aria-label="Next photo">
          →
        </button>
      </div>
    </section>
    """
  end
end
