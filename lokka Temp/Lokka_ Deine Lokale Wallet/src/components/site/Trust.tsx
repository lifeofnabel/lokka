import { Heart } from "lucide-react";

export function Trust() {
  return (
    <section className="px-5 py-8">
      <div className="mx-auto max-w-md">
        <div className="rounded-3xl bg-primary-soft/60 border border-primary/10 p-6 text-center">
          <div className="mx-auto h-10 w-10 rounded-full bg-card flex items-center justify-center text-primary shadow-[var(--shadow-soft)]">
            <Heart className="h-5 w-5" />
          </div>
          <h3 className="mt-3 text-base font-bold">
            Für lokale Lieblingsläden gemacht
          </h3>
          <p className="mt-1.5 text-[13px] text-muted-foreground max-w-xs mx-auto">
            Unterstütze Shops in deiner Nähe — mit jedem Stempel.
          </p>
        </div>
      </div>
    </section>
  );
}
