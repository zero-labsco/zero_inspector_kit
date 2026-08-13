import type { DocsThemeConfig } from 'nextra-theme-docs'
import React from 'react'

const config: DocsThemeConfig = {
  logo: (
    <span className="ac-logo">
      <span className="ac-logo-leaf">🌿</span> Zero Inspector Kit
    </span>
  ),
  project: {
    link: 'https://github.com/zero-labsco/zero_inspector_kit'
  },
  docsRepositoryBase:
    'https://github.com/zero-labsco/zero_inspector_kit/tree/main/website',
  footer: {
    content: 'Zero Inspector Kit · GPL-3.0'
  },
  // Keep it light & cozy — no dark mode for the island vibe
  darkMode: false,
  search: {
    placeholder: '🔍 Search the island…'
  },
  editLink: {
    content: '✏️ Edit this page on GitHub'
  },
  feedback: {
    content: '💬 Questions? Open an issue'
  },
  sidebar: {
    defaultMenuCollapseLevel: 1
  },
  toc: {
    backToTop: '⬆️ Back to top'
  },
  head: (
    <>
      <link rel="icon" href="/zero_inspector_kit/favicon.svg" type="image/svg+xml" />
      <link rel="preconnect" href="https://fonts.googleapis.com" />
      <link
        rel="preconnect"
        href="https://fonts.gstatic.com"
        crossOrigin="anonymous"
      />
      <link
        href="https://fonts.googleapis.com/css2?family=Baloo+2:wght@400;500;600;700;800&family=ZCOOL+KuaiLe&family=Noto+Sans+SC:wght@400;500;700&display=swap"
        rel="stylesheet"
      />
    </>
  )
}

export default config
