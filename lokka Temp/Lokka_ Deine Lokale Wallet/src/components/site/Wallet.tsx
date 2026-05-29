import wallet from "@/assets/wallet-card.png";
import { Check } from "lucide-react";

export function Wallet() {
  return (
    <section id="wallet" className="py-20 md:py-28" style={{ background: "var(--color-surface)" }}>
      <div className="mx-auto max-w-6xl px-4 grid md:grid-cols-2 gap-12 items-center">
        <div className="relative order-2 md:order-1">
          <div className="absolute -inset-8 bg-[radial-gradient(circle_at_center,var(--color-primary-soft),transparent_70%)] blur-2xl -z-10" />
          <img src={wallet} alt="Wallet Karte mit Stempeln und QR-Code" width={1024} height={1024} loading="lazy" className="w-full max-w-[480px] mx-auto" />
        </div>
        <div className="order-1 md:order-2">
          <span className="text-sm font-semibold text-primary">Deine lokale Wallet</span>
          <h2 className="mt-2 text-3xl md:text-4xl font-extrabold">Eine Karte. Alle Belohnungen.</h2>
          <p className="mt-4 text-muted-foreground max-w-md">
            Behalte deinen Fortschritt im Blick: Shop, Stempel, Punkte und QR-Code – immer griffbereit.
          </p>
          <ul className="mt-6 space-y-3">
            {["Stempelfortschritt live im Blick", "Direkt scannen an der Kasse", "Belohnungen automatisch freischalten"].map((t) => (
              <li key={t} className="flex items-start gap-3">
                <span className="mt-0.5 h-6 w-6 rounded-full bg-primary-soft text-primary flex items-center justify-center">
                  <Check className="h-3.5 w-3.5" />
                </span>
                <span className="text-sm">{t}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
