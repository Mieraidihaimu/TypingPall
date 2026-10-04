# TypingPall landing page

This folder is a no-build static site for a Cloudflare Pages launch. It contains the product website, the real product walkthrough, an editorial cut sheet for a short promotion video, and HN-ready copy.

## Cloudflare Pages setup

Create a Pages project from this GitHub repository and use:

| Setting | Value |
| --- | --- |
| Production branch | `main` |
| Root directory | `website` |
| Build command | `exit 0` |
| Build output directory | `.` |

Cloudflare Pages deploys the output directory and assigns a `*.pages.dev` subdomain. It will rebuild from the connected branch on later pushes. Confirm the deployed URL before putting it in the HN submission.

The site deliberately has no scripts, trackers, forms, or build dependencies. Preview locally with any static-file server, for example `python3 -m http.server 8000 --directory website` and open `http://localhost:8000`.

## Launch order

1. Deploy this directory and verify the video plays on the public `pages.dev` URL.
2. Replace the placeholder URL in `hn-submission.md` with the production URL.
3. Submit the title and production URL to Show HN, then add the prepared first comment.
4. Stay present for questions; use the reply guidelines rather than promoting for its own sake.

The current Cloudflare configuration matches the [official static HTML deployment guidance](https://developers.cloudflare.com/pages/framework-guides/deploy-anything/).
