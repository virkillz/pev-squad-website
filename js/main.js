document.addEventListener('DOMContentLoaded', function () {
  var toggle = document.querySelector('.nav-toggle');
  var links = document.querySelector('.nav-links');
  if (toggle && links) {
    toggle.addEventListener('click', function () {
      links.classList.toggle('open');
    });
  }

  var themeBtn = document.getElementById('themeSwitch');
  if (themeBtn) {
    var setIcon = function (theme) {
      var goingTo = theme === 'light' ? 'dark' : 'light';
      themeBtn.textContent = theme === 'light' ? '☾' : '☀';
      themeBtn.setAttribute('aria-label', 'Switch to ' + goingTo + ' mode');
    };
    setIcon(document.documentElement.getAttribute('data-theme') || 'dark');
    themeBtn.addEventListener('click', function () {
      var current = document.documentElement.getAttribute('data-theme') || 'dark';
      var next = current === 'light' ? 'dark' : 'light';
      document.documentElement.setAttribute('data-theme', next);
      try { localStorage.setItem('pev-theme', next); } catch (e) {}
      setIcon(next);
    });
  }
});
