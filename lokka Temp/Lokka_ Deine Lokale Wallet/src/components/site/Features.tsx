import { Tag, Stamp, Ticket } from "lucide-react";

const items = [
  { icon: Tag, title: "Deals entdecken", text: "Frisch aus der Nachbarschaft." },
  { icon: Stamp, title: "Stempel sammeln", text: "Jeder Besuch zählt." },
  { icon: Ticket, title: "Gutscheine sichern", text: "An der Kasse zeigen." },
];

export function Features() {
  return (
    <section className="px-5 py-8">
      <div className="mx-auto max-w-md">
        <h2 className="text-lg font-bold px-1">Was Lokka kann</h2>
        <div className="mt-3 grid gap-2.5">
          {items.map(({ icon: Icon, title, text }) => (
            <div
              key={title}
              className="flex items-center gap-3 rounded-2xl bg-card border border-border/60 p-3.5 shadow-[var(--shadow-soft)]"
            >
              <div className="h-10 w-10 shrink-0 rounded-xl bg-primary-soft flex items-center justify-center text-primary">
                <Icon className="h-5 w-5" />
              </div>
              <div className="min-w-0">
                <h3 className="text-[15px] font-semibold leading-tight">{title}</h3>
                <p className="text-[13px] text-muted-foreground leading-tight mt-0.5">
                  {text}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
