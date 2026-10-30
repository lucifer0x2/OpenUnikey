#!/usr/bin/env bash
# Downloads long Vietnamese texts for typing checks into Tests/Corpus (not
# committed): Wikipedia articles as plain text, plus Truyện Kiều from
# Wikisource. Usage: scripts/fetch-corpus.sh [title...]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Tests/Corpus"
UA="OpenUnikey-corpus/0.1 (typing tests)"
mkdir -p "$OUT"

TITLES=("$@")
if [ ${#TITLES[@]} -eq 0 ]; then
  TITLES=("Việt Nam" "Hà Nội" "Thành phố Hồ Chí Minh" "Lịch sử Việt Nam" "Tiếng Việt"
          "Nguyễn Du" "Phở" "Văn học Việt Nam" "Chiến tranh Việt Nam" "Áo dài")
fi

# Reads a MediaWiki JSON reply on stdin and prints the plain text it holds.
extract() {
  python3 -I -c '
import html, json, re, sys
data = json.load(sys.stdin)
if "parse" in data:  # Wikisource: rendered HTML
    text = data["parse"]["text"]["*"]
    text = re.sub(r"<(style|script)[^>]*>.*?</\1>", "", text, flags=re.S)
    text = re.sub(r"<br\s*/?>|</p>|</div>|</dd>|</li>", "\n", text)
    text = html.unescape(re.sub(r"<[^>]+>", "", text))
else:  # Wikipedia: plain-text extract
    text = next(iter(data["query"]["pages"].values())).get("extract", "")
text = re.sub(r"^=+.*=+$", "", text, flags=re.M)  # drop section headings
print(text)
'
}

for title in "${TITLES[@]}"; do
  file="$OUT/wiki-$(echo "$title" | tr ' ' '_').txt"
  curl -sfG -A "$UA" "https://vi.wikipedia.org/w/api.php" \
    --data-urlencode "action=query" --data-urlencode "prop=extracts" \
    --data-urlencode "explaintext=1" --data-urlencode "format=json" \
    --data-urlencode "titles=$title" | extract > "$file"
  echo "$(wc -w < "$file" | tr -d ' ') words  $file"
  sleep 1 # stay well under the API rate limit
done

file="$OUT/wikisource-Truyen_Kieu.txt"
if curl -sfG -A "$UA" "https://vi.wikisource.org/w/api.php" \
  --data-urlencode "action=parse" --data-urlencode "format=json" \
  --data-urlencode "prop=text" --data-urlencode "page=Truyện Kiều" | extract > "$file"; then
  echo "$(wc -w < "$file" | tr -d ' ') words  $file"
else
  rm -f "$file"
  echo "skipped Wikisource (rate limited or unavailable); run again later" >&2
fi
