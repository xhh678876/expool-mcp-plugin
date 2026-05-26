# Publishing expool-mcp-plugin

This package can be distributed in two ways:

1. Claude Code marketplace / GitHub checkout.
2. npm / npx installer package.
3. Local npm tarball for internal transfer before registry publishing.

## Release check

Run this before publishing:

```bash
npm run release:check
```

It verifies:

- Node, Bash, and Python syntax.
- Codex plugin manifest shape when the local validator is available.
- npm package contents, including `.codex-plugin/plugin.json`.
- no generated Python bytecode in the packed package.

## GitHub / Claude Code marketplace

The repository root already contains `.claude-plugin/marketplace.json`.
Publish it as a normal GitHub repository:

```bash
git init
git add .
git commit -m "release expool plugin vX.Y.Z"
git branch -M main
git remote add origin git@github.com:xhh666/expool-mcp-plugin.git
git push -u origin main
```

Users install from GitHub:

```bash
claude plugin marketplace add https://github.com/xhh666/expool-mcp-plugin
claude plugin install expool
npx --yes git+https://github.com/xhh666/expool-mcp-plugin.git install \
  --agents claude,codex,openclaw,hermes \
  --base <gateway-from-portal-/plugins>
```

## npm

Authenticate first:

```bash
npm login
```

Then publish:

```bash
npm run publish:npm
```

By default the script publishes the scoped package as public with tag
`latest`. Override when needed:

```bash
NPM_TAG=next NPM_PUBLISH_ACCESS=public npm run publish:npm
```

Users install/register with:

```bash
npx @haohui666/expool-plugin install --agents claude,codex,openclaw,hermes \
  --base <gateway-from-portal-/plugins>
npx @haohui666/expool-plugin pair expair_...
npx @haohui666/expool-plugin bind-api expk_...
npx @haohui666/expool-plugin auto on --sources claude-code,codex,hermes
```

## Local tarball

When npm publish is unavailable, produce an installable package file:

```bash
npm run release:artifact
npm install -g ./dist/chuangzhi-expool-plugin-*.tgz
expool-plugin install --agents claude,codex,openclaw,hermes \
  --base <gateway-from-portal-/plugins>
```

The `dist/` directory is ignored by git and excluded from the npm package.
When the sibling `experience-pool/dist-public/` directory exists, the same
command copies the package into `dist-public/plugins/` as both the versioned
tarball and `expool.tgz`, with `.sha256` files. The portal serves that file at:

```text
<gateway>/plugins/expool.tgz
```

The portal also serves a sha256-checking installer:

```bash
curl --noproxy '*' -fsSL <gateway>/plugins/install.sh | bash
```

Use the portal-generated command for nat2/code-server environments. It downloads
with `curl --noproxy '*'` first, then installs the local file; direct
`npm install -g https://nat2.../expool.tgz` can be intercepted by shell proxy
settings on some machines.

## Current machine status

This workspace can build and pack the npm package, but it is not authenticated
to npm. The configured GitHub repository currently does not exist or this
machine lacks access to it. Actual remote publishing needs repository creation
plus npm credentials, or must be run from a logged-in release machine.

Before publishing a package that advertises pairing-code binding, verify the
target gateway is upgraded:

```bash
EXPOOL_RELEASE_BASE=<gateway-url> npm run gateway:check
```
