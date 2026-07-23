# Build and deploy web

The `Web` export preset builds the game in the same portrait format as the
phone version. In a desktop browser, the game is centered and letterboxed to a
9:16 viewport so UI scale and aspect stay consistent. Its fullscreen button
requests browser fullscreen after a tap, because browsers do not allow pages to
enter fullscreen automatically.

## Automatic builds

GitHub Actions builds the web version on pull requests, pushes to `main`, and
manual workflow runs. The downloadable artifact is named
`the-road-north-web`.

Pushes to `main` and manual workflow runs also deploy the same web build to
GitHub Pages.

## Enable GitHub Pages

1. Push the repository to GitHub.
2. Open **Settings > Pages** in the repository.
3. Under **Build and deployment**, set **Source** to **GitHub Actions**.
4. Run **Deploy game to GitHub Pages** from the Actions tab, or push to `main`.

The deployed game will be available at:

```text
https://reicher.github.io/The-Road-North/
```

## Build locally

Install the Godot 4.6.3 export templates, then run:

```sh
godot --headless --path . --export-release Web build/web/index.html
```

Serve the build through HTTP for local testing:

```sh
python3 -m http.server 8000 --directory build/web
```
