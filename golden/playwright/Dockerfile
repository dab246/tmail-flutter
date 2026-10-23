# Pixel goldens render in this image, locally and in CI: same engines, same
# fonts, same pixels. Changing anything here regenerates every pixel golden,
# in a pull request of its own.
FROM mcr.microsoft.com/playwright:v1.52.0-noble@sha256:a021500a801bab0611049217ffad6b9697d827205c15babb86a53bc1a61c02d5

# Android webviews resolve sans-serif to Roboto, serif to Noto Serif and
# monospace to Droid Sans Mono, whose successor is Noto Mono. Versions are
# pinned: a font update must fail the build, not move pixels silently.
#
# optipng shrinks regenerated goldens losslessly (about a third); Playwright
# compares decoded pixels, so optimized goldens compare exactly the same.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      fonts-roboto-unhinted=2:0~20170802-3 \
      fonts-noto-core=20201225-2 \
      fonts-noto-mono=20201225-2 \
      optipng=0.7.8+ds-1build2 \
 && rm -rf /var/lib/apt/lists/*
