import walletHero from "@/assets/wallet-hero.png";
import { ArrowRight, PlayCircle } from "lucide-react";

export function Hero() {
  return (
    <section className="px-5 pt-6 pb-10">
      <div className="mx-auto max-w-md flex flex-col items-center text-center">
        <span className="inline-flex items-center gap-1.5 rounded-full bg-primary-soft px-3 py-1 text-[11px] font-semibold text-primary-foreground/80">
          <span className="h-1.5 w-1.5 rounded-full bg-primary" />
          Deine lokale Wallet
        </span>

        <h1 className="mt-4 text-[34px] leading-[1.05] font-extrabold tracking-tight">
          Lokale Deals.
          <br />
          <span className="text-primary">Direkt in deiner Wallet.</span>
        </h1>

        <p className="mt-3 text-[15px] text-muted-foreground max-w-xs">
          Entdecke Shops, sammle Stempel und sichere dir Vorteile in deiner Nähe.
        </p>

        <div className="mt-5 w-full max-w-[280px] mx-auto">
          <img
            src={walletHero}
            alt="Lokka Wallet Karte mit Stempeln"
            width={896}
            height={896}
            className="w-full drop-shadow-[0_20px_40px_rgba(20,80,90,0.18)]"
          />
        </div>

        <div id="login" className="mt-6 w-full flex flex-col items-center gap-2.5">
          <a href="#login" className="btn-primary w-full">
            Einloggen <ArrowRight className="h-4 w-4" />
          </a>
          <a href="#register" className="text-sm text-muted-foreground">
            Noch kein Konto?{" "}
            <span className="text-primary font-semibold">Registrieren</span>
          </a>
          <a href="#demo" className="btn-secondary w-full mt-1">
            <PlayCircle className="h-4 w-4" /> Demo ansehen
          </a>
        </div>

        <a
          href="#business"
          className="mt-5 text-xs text-muted-foreground/70 hover:text-foreground underline underline-offset-4"
        >
          Geschäftlich? Für Händler einloggen
        </a>
      </div>
    </section>
  );
}
