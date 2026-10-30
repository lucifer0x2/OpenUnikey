#!/usr/bin/env bash
# Opens a throwaway Chrome instance (its own temporary profile, so the user's
# Chrome is untouched) showing a field that mirrors its text into the window
# title, and prints the instance's pid for the typing harness:
#
#   PID=$(scripts/chromium-test-page.sh [textarea|editable])
#   scripts/run-harness.sh --external "$PID" --corpus FILE...
#   kill "$PID"   # when done
#
# "editable" uses a plain contenteditable div; "prosemirror" a ProseMirror
# editor (loaded from esm.sh), the kind of rich editor chat apps use.
set -euo pipefail

KIND="${1:-textarea}"
DIR="${TMPDIR:-/tmp}/openunikey-chrome"
PAGE="$DIR/$KIND.html"
mkdir -p "$DIR"
if [ "$KIND" = "prosemirror" ]; then
  cat > "$PAGE" <<'HTML'
<!doctype html><meta charset="utf-8"><title>OU:</title>
<div id="ed" style="min-height:90vh;font-size:15px"></div>
<script type="module">
import {EditorState} from "https://esm.sh/prosemirror-state";
import {EditorView} from "https://esm.sh/prosemirror-view";
import {schema} from "https://esm.sh/prosemirror-schema-basic";
import {keymap} from "https://esm.sh/prosemirror-keymap";
import {baseKeymap} from "https://esm.sh/prosemirror-commands";
const view = new EditorView(document.getElementById("ed"), {
  state: EditorState.create({schema, plugins: [keymap(baseKeymap)]}),
  dispatchTransaction(tr) {
    view.updateState(view.state.apply(tr));
    document.title = "OU:" + view.state.doc.textContent;
  },
});
view.focus();
</script>
HTML
elif [ "$KIND" = "editable" ]; then
  FIELD='<div id="f" contenteditable="true" spellcheck="false" style="min-height:90vh;font-size:15px" oninput="document.title=\x27OU:\x27+this.innerText"></div>'
else
  FIELD='<textarea id="f" spellcheck="false" style="width:100%;height:90vh;font-size:15px" oninput="document.title=\x27OU:\x27+this.value"></textarea>'
fi
if [ "$KIND" != "prosemirror" ]; then
  printf '<!doctype html><meta charset="utf-8"><title>OU:</title>%b<script>document.getElementById("f").focus()</script>\n' "$FIELD" > "$PAGE"
fi

open -na "Google Chrome" --args --user-data-dir="$DIR/profile" --no-first-run \
  --no-default-browser-check --app="file://$PAGE"
for _ in $(seq 1 50); do
  PID="$(pgrep -f "MacOS/Google Chrome --user-data-dir=$DIR/profile" | head -1 || true)"
  [ -n "$PID" ] && break
  sleep 0.2
done
[ -n "${PID:-}" ] || { echo "Chrome did not start" >&2; exit 1; }
sleep 4 # let the page (and its modules) load and take focus
echo "$PID"
