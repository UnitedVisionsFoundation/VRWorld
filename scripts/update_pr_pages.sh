#!/bin/bash

set -e

REPO="${GITHUB_REPOSITORY}"
TOKEN="${GITHUB_TOKEN}"
API="https://api.github.com"

if [ -z "$TOKEN" ]; then
  echo "GITHUB_TOKEN missing" >&2
  exit 1
fi

pr_json=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$API/repos/$REPO/pulls?state=open&sort=created&direction=desc")

latest_url=""
pr_items="<ul>"

len=$(echo "$pr_json" | jq 'length')
if [ "$len" -eq 0 ]; then
  echo "No open PRs" >&2
fi

for row in $(echo "$pr_json" | jq -r '.[] | @base64'); do
  _jq() { echo "$row" | base64 --decode | jq -r "$1"; }
  number=$(_jq '.number')
  title=$(_jq '.title')
  sha=$(_jq '.head.sha')

  statuses=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$API/repos/$REPO/commits/$sha/statuses")
  url=$(echo "$statuses" | jq -r '[.[] | select(.target_url | test("netlify.app"))][0].target_url')

  if [ "$url" = "null" ] || [ -z "$url" ]; then
    continue
  fi
  if [ -z "$latest_url" ]; then
    latest_url="$url"
  fi
  pr_items+="<li><a href=\"$url\">PR #$number: $title</a></li>"

done

pr_items+="</ul>"

cat > pr.html <<HTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>PR Previews</title>
</head>
<body>
<h1>Open PR Preview Links</h1>
$pr_items
</body>
</html>
HTML

if [ -n "$latest_url" ]; then
cat > latest-pr.html <<HTML
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="refresh" content="0; url=$latest_url">
  <title>Latest PR Preview</title>
</head>
<body>
<p><a href="$latest_url">Redirect to latest preview</a></p>
</body>
</html>
HTML
fi
