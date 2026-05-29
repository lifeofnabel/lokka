import { createFileRoute } from "@tanstack/react-router";
import { Nav } from "@/components/site/Nav";
import { Hero } from "@/components/site/Hero";
import { Features } from "@/components/site/Features";
import { HowItWorks } from "@/components/site/HowItWorks";
import { Trust } from "@/components/site/Trust";
import { Footer } from "@/components/site/Footer";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Lokka – Deine lokale Wallet" },
      {
        name: "description",
        content:
          "Lokale Deals, Stempelkarten und Gutscheine in einer einfachen Wallet. Entdecke Shops in deiner Nähe.",
      },
      { property: "og:title", content: "Lokka – Deine lokale Wallet" },
      {
        property: "og:description",
        content: "Lokale Deals, Stempel und Vorteile in deiner Nähe.",
      },
    ],
  }),
  component: Index,
});

function Index() {
  return (
    <main className="min-h-screen bg-background">
      <Nav />
      <Hero />
      <Features />
      <HowItWorks />
      <Trust />
      <Footer />
    </main>
  );
}
