// Gallery lightbox, ported from the prototype's kinetic.js.
// Attach to the element wrapping the photo grids (phx-hook="Lightbox"); the
// #lightbox dialog lives elsewhere on the page with phx-update="ignore".
// Tiles are real links to the large image, so without JS they still work.

const pad = n => (n < 10 ? "0" : "") + n

export const Lightbox = {
  mounted() {
    this.box = document.getElementById("lightbox")
    if (!this.box) return

    this.current = 0
    this.lastFocus = null
    this.img = this.box.querySelector(".lb-img")
    this.titleEl = this.box.querySelector(".lb-title")
    this.descEl = this.box.querySelector(".lb-desc")
    this.metaEl = this.box.querySelector(".lb-meta")
    this.countEl = this.box.querySelector(".lb-count")
    this.closeBtn = this.box.querySelector(".lb-close")

    this.onTileClick = e => {
      const tile = e.target.closest(".photo-tile")
      if (!tile || !this.el.contains(tile)) return
      e.preventDefault()
      this.open(this.tiles().indexOf(tile))
    }
    this.el.addEventListener("click", this.onTileClick)

    this.onPrev = () => this.show(this.current - 1)
    this.onNext = () => this.show(this.current + 1)
    this.onClose = () => this.close()
    this.onStage = e => { if (e.target === e.currentTarget) this.close() }
    this.box.querySelector(".lb-prev").addEventListener("click", this.onPrev)
    this.box.querySelector(".lb-next").addEventListener("click", this.onNext)
    this.closeBtn.addEventListener("click", this.onClose)
    this.box.querySelector(".lb-stage").addEventListener("click", this.onStage)

    this.onKey = e => {
      if (this.box.hidden) return
      if (e.key === "Escape") this.close()
      else if (e.key === "ArrowLeft") this.show(this.current - 1)
      else if (e.key === "ArrowRight") this.show(this.current + 1)
      else if (e.key === "Tab") {
        // Keep focus inside the dialog while it is open
        const focusable = this.box.querySelectorAll("button")
        const first = focusable[0]
        const last = focusable[focusable.length - 1]
        if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus() }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus() }
      }
    }
    document.addEventListener("keydown", this.onKey)
  },

  destroyed() {
    if (!this.box) return
    document.removeEventListener("keydown", this.onKey)
    this.box.querySelector(".lb-prev").removeEventListener("click", this.onPrev)
    this.box.querySelector(".lb-next").removeEventListener("click", this.onNext)
    this.closeBtn.removeEventListener("click", this.onClose)
    this.box.querySelector(".lb-stage").removeEventListener("click", this.onStage)
    document.body.style.overflow = ""
  },

  tiles() {
    return Array.from(this.el.querySelectorAll(".photo-tile"))
  },

  show(i) {
    const tiles = this.tiles()
    if (!tiles.length) return
    this.current = (i + tiles.length) % tiles.length // wraps both ways
    const tile = tiles[this.current]
    const thumb = tile.querySelector("img")

    this.img.src = tile.getAttribute("href")
    this.img.alt = thumb ? thumb.alt : ""
    this.titleEl.textContent = tile.dataset.title || ""
    this.metaEl.textContent = tile.dataset.meta || ""
    const desc = tile.dataset.desc || ""
    this.descEl.textContent = desc
    this.descEl.hidden = !desc
    this.countEl.textContent = pad(this.current + 1) + " / " + pad(tiles.length)
  },

  open(i) {
    this.lastFocus = document.activeElement
    this.show(i)
    this.box.hidden = false
    document.body.style.overflow = "hidden"
    this.closeBtn.focus()
  },

  close() {
    this.box.hidden = true
    document.body.style.overflow = ""
    if (this.lastFocus && this.lastFocus.focus) this.lastFocus.focus()
  },
}
