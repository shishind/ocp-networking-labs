import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'OCP Networking Labs',
  tagline: 'Zero to Expert in 7 Weeks',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  // GitHub Pages configuration
  url: 'https://shishind.github.io',
  baseUrl: '/ocp-networking-labs/',

  organizationName: 'shishind',
  projectName: 'ocp-networking-labs',

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/shishind/ocp-networking-labs/edit/main/website/',
          remarkPlugins: [],
          rehypePlugins: [],
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/ocp-networking-social-card.jpg',
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'OCP Networking Labs',
      logo: {
        alt: 'OCP Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'doc',
          docId: 'intro',
          position: 'left',
          label: 'Start Learning',
        },
        {
          to: '/cheat-sheets/Master_Commands_QuickRef',
          label: 'Cheat Sheets',
          position: 'left',
        },
        {
          href: 'https://github.com/shishind/ocp-networking-labs',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Learning Path',
          items: [
            {
              label: 'Week 1-2: Core Networking',
              to: '/week1-2/D1_OSI_Model',
            },
            {
              label: 'Week 3-4: Linux & Containers',
              to: '/week3-4/D15_Network_Namespaces',
            },
            {
              label: 'Week 5-6: Kubernetes',
              to: '/week5-6/D29_kind_Setup',
            },
            {
              label: 'Week 7: OpenShift',
              to: '/week7/D43_OVS_Fundamentals',
            },
          ],
        },
        {
          title: 'Resources',
          items: [
            {
              label: 'Cheat Sheets',
              to: '/cheat-sheets/Master_Commands_QuickRef',
            },
            {
              label: 'GitHub Repository',
              href: 'https://github.com/shishind/ocp-networking-labs',
            },
            {
              label: 'Report Issues',
              href: 'https://github.com/shishind/ocp-networking-labs/issues',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'OpenShift Docs',
              href: 'https://docs.openshift.com',
            },
            {
              label: 'Kubernetes Docs',
              href: 'https://kubernetes.io/docs',
            },
            {
              label: 'Red Hat Developer',
              href: 'https://developers.redhat.com',
            },
          ],
        },
      ],
      copyright: `OCP Networking Labs © ${new Date().getFullYear()}. Licensed under MIT. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'yaml', 'json'],
    },
    algolia: undefined, // Add Algolia search later if needed
  } satisfies Preset.ThemeConfig,
};

export default config;
