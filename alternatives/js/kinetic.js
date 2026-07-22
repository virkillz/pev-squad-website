/* PEV Squad — "Kinetic" direction.
   Mobile nav toggle, live date stamp, and demo filter tags. */

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

  /* Filter tags — visual only, same as the original prototype ------------ */
  document.querySelectorAll('.filters').forEach(function (group) {
    group.addEventListener('click', function (e) {
      var tag = e.target.closest('.filter-tag');
      if (!tag || !group.contains(tag)) return;
      e.preventDefault();
      group.querySelectorAll('.filter-tag').forEach(function (t) {
        t.classList.remove('active');
      });
      tag.classList.add('active');
    });
  });

});
