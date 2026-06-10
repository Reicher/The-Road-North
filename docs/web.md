# Deploy to GitHub Pages

The `Web` export preset builds a full-viewport version of the game. Its
fullscreen button requests browser fullscreen after a tap, because browsers do
not allow pages to enter fullscreen automatically.

## Enable GitHub Pages

1. Push the repository to GitHub.
2. Open **Settings > Pages** in the repository.
3. Under **Build and deployment**, set **Source** to **GitHub Actions**.
4. Run **Deploy game to GitHub Pages** from the Actions tab, or push to `main`.

The deployed game will be available at:

```text
https://reicher.github.io/Road-to-Karlskoga/
```

## Build locally

Install the Godot 4.6.3 export templates, then run:

```sh
"/Users/robin.reicher/Downloads/Godot 2.app/Contents/MacOS/Godot" \
  --headless --path . --export-release Web build/web/index.html
```

Serve the build through HTTP for local testing:

```sh
python3 -m http.server 8000 --directory build/web
```
