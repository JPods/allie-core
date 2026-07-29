// CityRoadkills shared navigation
// Usage: <div class="tabs" id="crk-nav" data-active="murder"></div>
// Script auto-detects subfolder depth for correct relative paths

(function() {
  var nav = document.getElementById('crk-nav');
  if (!nav) return;
  var active = nav.getAttribute('data-active') || '';

  // Detect subfolder: if URL path has a city folder like /tx_arlington/
  var path = window.location.pathname;
  var pre = '';
  if (/\/[a-z]{2}_[a-z]/.test(path) || /\/[a-z]{2}_[A-Z]/.test(path)) {
    pre = '../';
  }

  var tabs = [
    ['murder', 'Stop Child Murder', 'index.html'],
    ['reduction', '60% Reduction', 'sovereign-immunity.html'],
    ['constitutional', 'Constitutional', 'constitutional.html'],
    ['bottomup', 'BottomUp', 'bottomup.html'],
    ['arlington', 'Arlington', 'tx_arlington/'],
    ['paloalto', 'Palo Alto', 'ca_paloalto/'],
    ['columbia', 'Columbia', 'sc_columbia/'],
    ['greenville', 'Greenville', 'sc_greenville/'],
    ['tulsa', 'Tulsa', 'ok_tulsa/'],
    ['library', 'Library', 'index.html#panel-library'],
    ['template', 'Template', 'index.html#panel-template']
  ];

  var html = '';
  for (var i = 0; i < tabs.length; i++) {
    var t = tabs[i];
    var cls = t[0] === active ? ' active' : '';
    // For tab items that are JS-driven panels (library, template on index), use buttons
    if ((t[0] === 'library' || t[0] === 'template') && active === 'murder') {
      html += '<button class="tab' + cls + '" onclick="switchTab(\'' +
              (t[0] === 'library' ? 'library' : 'template') + '\',this)">' + t[1] + '</button>\n';
    } else {
      html += '<a class="tab' + cls + '" href="' + pre + t[2] + '">' + t[1] + '</a>\n';
    }
  }
  nav.innerHTML = html;
})();
