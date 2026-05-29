const steps = [
  { n: "1", t: "Shop finden", d: "Lokale Läden um dich." },
  { n: "2", t: "Karte speichern", d: "Direkt in der Wallet." },
  { n: "3", t: "Vorteil nutzen", d: "QR zeigen, fertig." },
];

export function HowItWorks() {
  return (
    <section className="px-5 py-8">
      <div className="mx-auto max-w-md">
        <h2 className="text-lg font-bold px-1">So funktioniert's</h2>
        <ol className="mt-3 grid gap-2.5">
          {steps.map((s) => (
            <li
              key={s.n}
              className="flex items-center gap-3 rounded-2xl bg-card border border-border/60 p-3.5"
            >
              <span className="h-8 w-8 shrink-0 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-sm font-bold">
                {s.n}
              </span>
              <div className="min-w-0">
                <h3 className="text-[15px] font-semibold leading-tight">{s.t}</h3>
                <p className="text-[13px] text-muted-foreground leading-tight mt-0.5">
                  {s.d}
                </p>
              </div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
