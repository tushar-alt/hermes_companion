/// Hard-reload the page (web builds).
library;

import 'dart:html' as html;

void hardReload() {
  html.window.location.reload();
}
