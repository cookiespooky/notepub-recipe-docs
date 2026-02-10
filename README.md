# Notepub Documentation Template

Template repository for building and deploying documentation websites with Notepub and GitHub Pages.

## Features

- Docs-first structure (`/` is the documentation home page)
- Hub-based sidebar navigation
- Markdown + frontmatter content model
- Search page and search modal
- SEO/metadata defaults (sitemap, robots, OpenGraph, JSON-LD)
- Branding from content/config:
  `content/home.md` frontmatter `title` is used as the header brand name,
  `site.default_og_image` in `config.yaml` is used as the header brand logo
- `llms.txt` and `llms-full.txt` for LLM indexing
- GitHub Actions workflow for automatic deploy

## Use This Template

1. Click **Use this template** in GitHub.
2. Create a new repository.
3. Push changes to `main`.
4. Open **Settings -> Pages** and ensure source is **GitHub Actions**.
5. Wait for the `Deploy Docs Template to GitHub Pages` workflow to finish.

The workflow computes `base_url` from your repository URL and deploys `dist/` automatically.

## Content Structure

- `content/home.md` - documentation home page (route `/`)
- `content/*.md` - pages, hubs, and articles

Minimal frontmatter example:

```yaml
type: article
slug: configuration
title: Configuration
description: Key settings in config.yaml and rules.yaml.
hub: [reference]
order: 10
```

## Local Development

Build:

```bash
NOTEPUB_BIN=/path/to/notepub ./scripts/build.sh
```

Serve static output:

```bash
python3 -m http.server 9000 -d dist
```

Open: `http://127.0.0.1:9000/`

## Template Notes

After creating your own repo from this template, update these values:

- `site.title` and `site.description` in `config.yaml`
- `content/home.md` -> `title` (shown as brand name in header)
- `site.default_og_image` in `config.yaml` (used as brand logo in header and default OG image)
- Yandex Metrika ID in `theme/templates/layout.html` (optional)
- `theme/assets/llms.txt` and `theme/assets/llms-full.txt` placeholders (`<username>`, `<repo>`)
