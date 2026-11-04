// Home page carousel of featured gallery photos.
// The track is a horizontal scroll-snap strip, so swiping and trackpads work
// without JS; this hook adds prev/next, the "01 / 05" counter and autoplay.
// Autoplay pauses on hover/focus, when the tab is hidden, and is off for
// people who prefer reduced motion.

const pad = n => (n < 10 ? "0" : "") + n
const INTERVAL = 6000

export const Carousel = {
  mounted() {
    this.track = this.el.querySelector(".carousel-track")
    this.counter = this.el.querySelector('[data-carousel="current"]')
    this.paused = false
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    this.onClick = e => {
      const btn = e.target.closest("[data-carousel]")
      if (!btn) return
      if (btn.dataset.carousel === "prev") this.go(this.index() - 1)
      if (btn.dataset.carousel === "next") this.go(this.index() + 1)
      this.restart()
    }
    this.el.addEventListener("click", this.onClick)

    this.onKey = e => {
      if (e.key === "ArrowLeft") { e.preventDefault(); this.go(this.index() - 1) }
      if (e.key === "ArrowRight") { e.preventDefault(); this.go(this.index() + 1) }
    }
    this.track.addEventListener("keydown", this.onKey)

    this.onScroll = () => {
      if (this.counter) this.counter.textContent = pad(this.index() + 1)
    }
    this.track.addEventListener("scroll", this.onScroll, {passive: true})

    this.pause = () => { this.paused = true }
    this.resume = () => { this.paused = false }
    this.el.addEventListener("mouseenter", this.pause)
    this.el.addEventListener("mouseleave", this.resume)
    this.el.addEventListener("focusin", this.pause)
    this.el.addEventListener("focusout", this.resume)

    this.restart()
  },

  updated() { this.onScroll() },

  destroyed() { clearInterval(this.timer) },

  slides() { return Array.from(this.track.children) },

  index() {
    const width = this.track.clientWidth || 1
    return Math.round(this.track.scrollLeft / width)
  },

  go(i) {
    const count = this.slides().length
    if (count === 0) return
    const next = (i + count) % count
    this.track.scrollTo({left: next * this.track.clientWidth, behavior: this.reduced ? "auto" : "smooth"})
  },

  restart() {
    clearInterval(this.timer)
    if (this.reduced || this.slides().length < 2) return
    this.timer = setInterval(() => {
      if (!this.paused && !document.hidden) this.go(this.index() + 1)
    }, INTERVAL)
  }
}
