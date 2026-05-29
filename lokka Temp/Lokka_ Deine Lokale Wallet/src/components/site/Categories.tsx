import food from "@/assets/cat-food.jpg";
import cafe from "@/assets/cat-cafe.jpg";
import beauty from "@/assets/cat-beauty.jpg";
import fitness from "@/assets/cat-fitness.jpg";
import kiosk from "@/assets/cat-kiosk.jpg";

const cats = [
  { label: "Food", img: food },
  { label: "Café", img: cafe },
  { label: "Beauty", img: beauty },
  { label: "Fitness", img: fitness },
  { label: "Kiosk", img: kiosk },
];

export function Categories() {
  return (
    <section className="py-20 md:py-28">
      <div className="mx-auto max-w-6xl px-4">
        <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-4">
          <div>
            <h2 className="text-3xl md:text-4xl font-extrabold">Entdecken statt suchen</h2>
            <p className="mt-3 text-muted-foreground max-w-md">Stöbere durch Kategorien und finde Läden in deiner Nähe.</p>
          </div>
        </div>

        <div className="mt-10 -mx-4 px-4 flex gap-4 overflow-x-auto pb-4 snap-x snap-mandatory scrollbar-none">
          {cats.map((c) => (
            <div key={c.label} className="snap-start shrink-0 w-[220px] sm:w-[260px]">
              <div className="relative h-[300px] rounded-[28px] overflow-hidden shadow-[var(--shadow-soft)] group">
                <img src={c.img} alt={c.label} width={768} height={768} loading="lazy" className="absolute inset-0 h-full w-full object-cover group-hover:scale-105 transition duration-500" />
                <div className="absolute inset-x-0 bottom-0 p-4 bg-gradient-to-t from-black/55 to-transparent">
                  <span className="inline-flex items-center gap-2 rounded-full bg-card/90 backdrop-blur px-3 py-1.5 text-sm font-semibold">
                    {c.label}
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
