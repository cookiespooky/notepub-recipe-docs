#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="${1:-./content}"

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "normalize-obsidian-embeds: directory not found: $ROOT_DIR"
  exit 1
fi

echo "normalize-obsidian-embeds: scanning $ROOT_DIR"

files=()
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(find "$ROOT_DIR" -type f -name '*.md' -print0)

if [[ "${#files[@]}" -eq 0 ]]; then
  echo "normalize-obsidian-embeds: no markdown files found"
  exit 0
fi

perl -0777 -i - "${files[@]}" <<'PERL'
use strict;
use warnings;

sub trim {
  my ($s) = @_;
  $s //= "";
  $s =~ s/^\s+|\s+$//g;
  return $s;
}

sub unquote {
  my ($v) = @_;
  $v = trim($v);
  $v =~ s/^"(.*)"$/$1/s;
  $v =~ s/^'(.*)'$/$1/s;
  return $v;
}

sub wiki_target {
  my ($raw) = @_;
  my $v = unquote($raw);
  if ($v =~ /^\[\[([^\]#|]+)(?:#[^\]|]+)?(?:\|[^\]]+)?\]\]$/) {
    return trim($1);
  }
  return $v;
}

sub basename_no_ext {
  my ($path) = @_;
  my $name = $path;
  $name =~ s!.*[/\\]!!;
  $name =~ s/\.md$//i;
  return $name;
}

my @files = @ARGV;
my %slug_by_name = ();
my %slug_by_name_lc = ();
my %content_by_file = ();

for my $file (@files) {
  local $/;
  open my $fh, '<', $file or die "open $file: $!";
  my $text = <$fh>;
  close $fh;

  $content_by_file{$file} = $text;

  my $base = basename_no_ext($file);
  my $slug = $base;
  if ($text =~ /\A---\r?\n([\s\S]*?)\r?\n---\r?\n/) {
    my $fm = $1;
    if ($fm =~ /^slug:\s*(.+?)\s*$/m) {
      my $candidate = unquote($1);
      $slug = $candidate if $candidate ne "";
    }
  }

  $slug_by_name{$base} = $slug;
  $slug_by_name{"$base.md"} = $slug;
  $slug_by_name_lc{lc($base)} = $slug;
  $slug_by_name_lc{lc("$base.md")} = $slug;
}

sub resolve_to_slug {
  my ($raw) = @_;
  my $target = wiki_target($raw);
  return $target if $target eq "";
  return $slug_by_name{$target} // $slug_by_name_lc{lc($target)} // $target;
}

sub parse_inline_list {
  my ($raw) = @_;
  my $v = trim($raw);
  return () if $v eq "";
  if ($v =~ /^\[(.*)\]$/s && $v !~ /^\[\[.*\]\]$/s) {
    my $inner = $1;
    my @parts = split /,/, $inner;
    my @vals = ();
    for my $part (@parts) {
      my $item = trim($part);
      push @vals, $item if $item ne "";
    }
    return @vals;
  }
  return ();
}

sub normalize_link_fields_frontmatter {
  my ($fm) = @_;
  my @lines = split /\n/, $fm, -1;
  my @out = ();
  my $i = 0;

  while ($i <= $#lines) {
    my $line = $lines[$i];

    if ($line =~ /^(hub|related):\s*(\S.*)$/) {
      my $field = $1;
      my $raw = $2;
      my @vals = parse_inline_list($raw);
      if (@vals == 0) {
        my $norm = resolve_to_slug($raw);
        @vals = ($norm) if $norm ne "";
      } else {
        @vals = map { resolve_to_slug($_) } @vals;
        @vals = grep { $_ ne "" } @vals;
      }
      push @out, "$field:";
      for my $val (@vals) {
        push @out, "  - \"$val\"";
      }
      $i++;
      next;
    }

    if ($line =~ /^(hub|related):\s*$/) {
      my $field = $1;
      my @vals = ();
      $i++;
      while ($i <= $#lines && $lines[$i] =~ /^[ \t]+-\s*(.*?)\s*$/) {
        my $norm = resolve_to_slug($1);
        push @vals, $norm if $norm ne "";
        $i++;
      }
      push @out, "$field:";
      for my $val (@vals) {
        push @out, "  - \"$val\"";
      }
      next;
    }

    push @out, $line;
    $i++;
  }

  return join("\n", @out);
}

for my $file (@files) {
  my $text = $content_by_file{$file};

  $text =~ s{\A---\r?\n([\s\S]*?)\r?\n---\r?\n}{
    my $fm = $1;
    my $norm = normalize_link_fields_frontmatter($fm);
    "---\n$norm\n---\n";
  }eg;

  $text =~ s{!\[\[([^\]|]+?\.(?:png|jpe?g|gif|webp|svg|avif|bmp|ico))(?:\#[^\]|]+)?(?:\|([^\]]+))?\]\]}{
    my $path = $1;
    my $alt = defined($2) ? $2 : "";
    $alt =~ s/^\s+|\s+$//g;
    $alt = "" if $alt =~ /^\d+(?:x\d+)?$/;
    $path =~ s{^\./}{};
    $path =~ s{^/+}{};
    "![$alt](/media/$path)"
  }egi;

  open my $out, '>', $file or die "write $file: $!";
  print {$out} $text;
  close $out;
}
PERL

echo "normalize-obsidian-embeds: done"
