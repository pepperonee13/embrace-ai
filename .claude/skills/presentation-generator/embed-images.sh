#!/usr/bin/env bash
# embed-images.sh — replaces local image src attributes with base64 data URIs
# Usage: bash embed-images.sh <output.html>
# Resolves relative paths first against the HTML file's directory,
# then against the current working directory.

set -euo pipefail

HTML_FILE="${1:?Usage: embed-images.sh <output.html>}"
HTML_DIR="$(cd "$(dirname "$HTML_FILE")" && pwd)"
CALL_DIR="$(pwd)"

# Pass both base directories into perl via -s flags
perl -i -s -0777 -pe '
  # Inline SVGs: replace <img src="*.svg" ...> with the raw SVG content
  s{<img\s+([^>]*?)src="(?!data:)(?!https?://)([^"]+\.svg)"([^>]*)>}{
    my ($pre, $src, $post) = ($1, $2, $3);
    my $abs;
    if ($src =~ m{^/}) {
      $abs = $src;
    } elsif (-f "$html_dir/$src") {
      $abs = "$html_dir/$src";
    } else {
      $abs = "$call_dir/$src";
    }
    if (-f $abs) {
      open(my $fh, "<:utf8", $abs) or die "Cannot open $abs: $!";
      local $/; my $svg = <$fh>; close $fh;
      # Strip XML declaration if present
      $svg =~ s/<\?xml[^?]*\?>\s*//;
      # Carry over class/style/width/height from the <img> tag if present
      my $extra = "$pre$post";
      if ($extra =~ /class="([^"]+)"/) { $svg =~ s/<svg\b/<svg class="$1"/; }
      if ($extra =~ /style="([^"]+)"/) { $svg =~ s/<svg\b/<svg style="$1"/; }
      $svg;
    } else {
      qq{<img ${pre}src="$src"${post}>};  # not found, leave unchanged
    }
  }gise;

  # Base64-embed remaining local images (non-SVG)
  s{src="(?!data:)(?!https?://)([^"]+)"}{
    my $src = $1;
    next if $src =~ /\.svg$/i;  # already handled above
    my $abs;
    if ($src =~ m{^/}) {
      $abs = $src;
    } elsif (-f "$html_dir/$src") {
      $abs = "$html_dir/$src";
    } else {
      $abs = "$call_dir/$src";
    }
    if (-f $abs) {
      my $ext = lc(($abs =~ /\.(\w+)$/)[0] // "");
      my %mime = (png=>"image/png", jpg=>"image/jpeg", jpeg=>"image/jpeg",
                  gif=>"image/gif", webp=>"image/webp");
      my $mime = $mime{$ext} // "application/octet-stream";
      open(my $fh, "<:raw", $abs) or die "Cannot open $abs: $!";
      local $/; my $raw = <$fh>; close $fh;
      require MIME::Base64;
      my $b64 = MIME::Base64::encode_base64($raw, "");
      qq{src="data:$mime;base64,$b64"};
    } else {
      qq{src="$src"};  # not a local file, leave unchanged
    }
  }ge;
' -- -html_dir="$HTML_DIR" -call_dir="$CALL_DIR" "$HTML_FILE"

echo "Done: local images embedded in $HTML_FILE"
