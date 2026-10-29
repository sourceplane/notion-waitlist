import "./globals.css";
import type { Metadata } from "next";
import localFont from "next/font/local";
import { Toaster } from "@/components/ui/sonner";
import { SITE_NAME, SITE_URL } from "./site";

// Figtree, self-hosted: the latin subset of its variable font from the
// @fontsource-variable package (OFL-1.1), emitted as a static asset by the
// build. The template loaded it with next/font/google, which fetches Google
// Fonts at build time and fails on GitHub's runners.
const FigtreeFont = localFont({
  src: "../node_modules/@fontsource-variable/figtree/files/figtree-latin-wght-normal.woff2",
  weight: "300 900",
});

// The Open Graph and Twitter cards are the template's, served as static
// assets from public/ and named in absolute URLs on metadataBase. (As
// app/opengraph-image.png, Next would compile each image into the Worker as
// a route; the two are 1.3 MB each.)
export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: SITE_NAME,
  description:
    "A simple Next.js waitlist template with Notion as CMS and Resend to send emails created with React Email and Cloudflare's rate limiting. Deployed on Cloudflare Workers.",
  openGraph: {
    siteName: SITE_NAME,
    url: "/",
    images: [{ url: "/opengraph-image.png", type: "image/png", width: 1280, height: 832 }],
  },
  twitter: {
    images: [{ url: "/twitter-image.png", type: "image/png", width: 1280, height: 832 }],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark" suppressHydrationWarning>
      <body className={FigtreeFont.className}>
        {children}
        <Toaster richColors position="top-center" />
      </body>
    </html>
  );
}
