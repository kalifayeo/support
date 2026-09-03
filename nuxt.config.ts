// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2026-01-01',
  devtools: { enabled: false },
  ssr: false, // build statique -> requis pour l'export Capacitor (web + mobile)

  modules: [
    '@nuxtjs/tailwindcss',
    '@nuxtjs/supabase',
    '@pinia/nuxt',
    '@vueuse/nuxt',
    '@nuxtjs/color-mode',
  ],

  colorMode: {
    preference: 'system',
    fallback: 'light',
    classSuffix: '',
  },

  supabase: {
    redirect: false, // on gère nous-mêmes les redirections dans middleware/auth.global.ts
  },

  app: {
    head: {
      title: 'Support — DSI',
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no' },
      ],
    },
    pageTransition: { name: 'page', mode: 'out-in' },
  },

  css: ['~/assets/css/main.css'],

  runtimeConfig: {
    // Clé secrète : disponible UNIQUEMENT côté serveur (server/api/*),
    // jamais exposée au navigateur. Ne jamais la mettre dans "public".
    supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
    public: {
      appName: 'Support',
      orgName: 'DSI',
      supabaseUrl: process.env.SUPABASE_URL,
    },
  },

  nitro: {
    preset: 'vercel',
    prerender: {
      crawlLinks: false,
    },
  },

  typescript: {
    strict: true,
  },
})
