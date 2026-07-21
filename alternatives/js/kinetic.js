/* Live date stamp in the hero meta strip — e.g. "JUL 22 WED". */
(function () {
  var months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  var days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  function updateDate() {
    var el = document.getElementById('current-date');
    if (!el) return;
    var now = new Date();
    el.innerText = months[now.getMonth()] + ' ' + now.getDate() + ' ' + days[now.getDay()];
  }

  updateDate();
})();
