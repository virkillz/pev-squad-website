/* PEV Squad — "Kinetic" direction.
   Mobile nav toggle, live date stamp, demo filter tags, gallery lightbox. */

document.addEventListener('DOMContentLoaded', function () {

  /* Mobile nav ---------------------------------------------------------- */
  var toggle = document.querySelector('.nav-toggle');
  var nav = document.querySelector('.mainnav');
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      var open = nav.classList.toggle('open');
      toggle.textContent = open ? 'CLOSE' : 'MENU';
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }

  /* Live date stamp in the hero meta strip — e.g. "22 JUL WED" ----------- */
  var stamp = document.getElementById('current-date');
  if (stamp) {
    var months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    var days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    var now = new Date();
    stamp.textContent = now.getDate() + ' ' + months[now.getMonth()] + ' ' + days[now.getDay()];
  }

  /* Filter tags ---------------------------------------------------------- */
  /* A group with data-filter-for="<grid id>" really filters that grid by each
     card's data-category. Groups without it stay visual-only. */
  document.querySelectorAll('.filters').forEach(function (group) {
    group.addEventListener('click', function (e) {
      var tag = e.target.closest('.filter-tag');
      if (!tag || !group.contains(tag)) return;
      e.preventDefault();

      group.querySelectorAll('.filter-tag').forEach(function (t) {
        t.classList.remove('active');
      });
      tag.classList.add('active');

      var gridId = group.getAttribute('data-filter-for');
      if (!gridId) return;
      var grid = document.getElementById(gridId);
      if (!grid) return;

      var want = tag.getAttribute('data-filter') || 'all';
      grid.querySelectorAll('[data-category]').forEach(function (card) {
        card.hidden = (want !== 'all' && card.getAttribute('data-category') !== want);
      });
    });
  });

  /* Gallery lightbox ----------------------------------------------------- */
  /* Tiles are real <a href="images/…"> links, so with JS off they still open
     the full image. Everything below is enhancement on top of that. */
  (function () {
    var grid = document.querySelector('[data-lightbox-grid]');
    var box = document.getElementById('lightbox');
    if (!grid || !box) return;

    var tiles = Array.prototype.slice.call(grid.querySelectorAll('.photo-tile'));
    if (!tiles.length) return;

    var imgEl = box.querySelector('.lb-img');
    var titleEl = box.querySelector('.lb-title');
    var descEl = box.querySelector('.lb-desc');
    var metaEl = box.querySelector('.lb-meta');
    var countEl = box.querySelector('.lb-count');
    var closeBtn = box.querySelector('.lb-close');
    var current = 0;
    var lastFocus = null;

    function pad(n) { return (n < 10 ? '0' : '') + n; }

    function show(i) {
      current = (i + tiles.length) % tiles.length;   // wraps both ways
      var tile = tiles[current];
      var thumb = tile.querySelector('img');

      imgEl.src = tile.getAttribute('href');
      imgEl.alt = thumb ? thumb.alt : '';
      titleEl.textContent = tile.dataset.title || '';
      metaEl.textContent = tile.dataset.meta || '';

      var desc = tile.dataset.desc || '';
      descEl.textContent = desc;
      descEl.hidden = !desc;

      countEl.textContent = pad(current + 1) + ' / ' + pad(tiles.length);
    }

    function open(i) {
      lastFocus = document.activeElement;
      show(i);
      box.hidden = false;
      document.body.style.overflow = 'hidden';
      closeBtn.focus();
    }

    function close() {
      box.hidden = true;
      document.body.style.overflow = '';
      if (lastFocus && lastFocus.focus) lastFocus.focus();
    }

    tiles.forEach(function (tile, i) {
      tile.addEventListener('click', function (e) {
        e.preventDefault();
        open(i);
      });
    });

    box.querySelector('.lb-prev').addEventListener('click', function () { show(current - 1); });
    box.querySelector('.lb-next').addEventListener('click', function () { show(current + 1); });
    closeBtn.addEventListener('click', close);

    /* Click the backdrop (the stage padding, not the image) to dismiss */
    box.querySelector('.lb-stage').addEventListener('click', function (e) {
      if (e.target === this) close();
    });

    document.addEventListener('keydown', function (e) {
      if (box.hidden) return;
      if (e.key === 'Escape') { close(); }
      else if (e.key === 'ArrowLeft') { show(current - 1); }
      else if (e.key === 'ArrowRight') { show(current + 1); }
      else if (e.key === 'Tab') {
        /* Keep focus inside the dialog while it is open */
        var focusable = box.querySelectorAll('button');
        var first = focusable[0];
        var last = focusable[focusable.length - 1];
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault(); last.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault(); first.focus();
        }
      }
    });
  })();

});
