import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'info.dsi.support',
  appName: 'Support',
  // Coquille locale minimale (écran de chargement) — le contenu réel vient
  // du site Vercel via server.url ci-dessous.
  webDir: 'mobile-shell',
  server: {
    // Remplacez par votre URL Vercel définitive si elle change (domaine
    // personnalisé, etc.). L'app mobile est un navigateur intégré qui
    // charge ce site en direct — toute mise à jour du site Vercel se
    // reflète immédiatement dans l'app, sans nouvelle publication d'APK.
    url: 'https://support-kappa-eight.vercel.app',
    androidScheme: 'https',
    cleartext: false,
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 800,
      backgroundColor: '#0f5c2a',
      androidSplashResourceName: 'splash',
      showSpinner: false,
    },
    StatusBar: {
      style: 'DARK',
    },
  },
};

export default config;
