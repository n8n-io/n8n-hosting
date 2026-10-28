# Build the chat.postMessage payload that announces a chart release.
#
#   gh release view v2.0.0 --json body,url,tagName,isPrerelease |
#     jq --arg channel C036AELNMV0 --arg app_version 3.0.1 -f scripts/slack-release-message.jq
#
# The input is the GitHub release that release-please wrote. Its body is
# Markdown, which Slack does not render, so this rewrites the parts
# release-please produces into Slack's mrkdwn and drops the per-commit links.

def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
def link($url; $label): "<\($url)|\($label)>";

(.body
  | sub("^## [^\n]*\n+"; "")
  | gsub(" \\(\\[[0-9a-f]{7,40}\\]\\(https://github\\.com/[^)]*/commit/[0-9a-f]+\\)\\)"; "")
  | esc
  | gsub("\\[(?<t>[^\\]\\n]+)\\]\\((?<u>https?://[^)\\s]+)\\)"; "<\(.u)|\(.t)>")
  | gsub("(?<p>^|\\n)### (?<h>[^\\n]+)"; "\(.p)*\(.h)*")
  | gsub("\\*\\*(?<b>[^*\\n]+)\\*\\*"; "*\(.b)*")
  | gsub("(?<p>^|\\n)\\* "; "\(.p)• ")
  | gsub("\\n{3,}"; "\n\n")
  | rtrimstr("\n")) as $notes
# Slack rejects a section over 3,000 characters, so a long changelog is cut
# at a line break and points at the release for the rest.
| (if ($notes | length) > 2900
   then ($notes[0:2800] | sub("\\n[^\\n]*$"; "")) + "\n\n…" + link(.url; "Read the full release notes")
   else $notes end) as $section
| {
    channel: $channel,
    text: "n8n Helm chart \(.tagName) released",
    unfurl_links: false,
    blocks: [
      { type: "header", text: { type: "plain_text", text: ":package: n8n Helm chart \(.tagName) released\(if .isPrerelease then " (pre-release)" else "" end)" } },
      { type: "section", text: { type: "mrkdwn", text: $section } },
      { type: "context", elements: [ { type: "mrkdwn", text: "Deploys n8n `\($app_version)` · \(link(.url; "View release"))" } ] }
    ]
  }
