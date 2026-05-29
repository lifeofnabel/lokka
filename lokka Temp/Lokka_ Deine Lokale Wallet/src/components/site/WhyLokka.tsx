import { Leaf, MapPin, Zap, Heart } from "lucide-react";

const items = [
  { icon: Leaf, t: "Keine Papierkarten", d: "Schluss mit verlorenen Stempelkarten im Geldbeutel." },
  { icon: Heart, t: "Alle Lieblingsläden", d: "An einem Ort, immer dabei." },
  { icon: MapPin, t: "Lokale Angebote", d: "Direkt sichtbar – ohne lange suchen." },
  { icon: Zap, t: "Schnell & einfach", d: "Modern, klar, ohne Schnickschnack." },
];

export function WhyLokka() {
  return (
    <section className="py-20 md:py-28">
      <div className="mx-auto max-w-6xl px-4">
        <h2 className="text-3xl md:text-4xl font-extrabold max-w-xl">Warum Lokka?</h2>

        <div className="mt-10 grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {items.map(({ icon: Icon, t, d }) => (
            <div key={t} className="rounded-[24px] p-6 bg-primary-soft/60 border border-border">
              <Icon className="h-6 w-6 text-primary" />
              <h3 className="mt-4 font-bold">{t}</h3>
              <p className="mt-1.5 text-sm text-muted-foreground">{d}</p>
            </div>
          ))}
        </div>

        <div className="mt-14 rounded-[32px] p-8 md:p-12 text-center" style={{ background: "var(--gradient-mint)" }}>
          <h3 className="text-2xl md:text-3xl font-extrabold">Bereit für deine lokale Wallet?</h3>
          <p className="mt-2 text-foreground/80 max-w-md mx-auto">Starte jetzt und entdecke, was direkt um die Ecke wartet.</p>
          <div className="mt-6 flex flex-col sm:flex-row gap-3 justify-center">
            <a href="#login" className="btn-primary">Einloggen</a>
            <a href="#register" className="btn-secondary">Konto erstellen</a>
          </div>
        </div>
      </div>
    </section>
  );
}
