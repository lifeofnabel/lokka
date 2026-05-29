export function Logo({ className = "" }: { className?: string }) {
  return (
    <div className={`flex items-center gap-2 ${className}`}>
      <div className="relative h-9 w-9 rounded-2xl bg-primary shadow-[var(--shadow-soft)] flex items-center justify-center">
        <span className="text-primary-foreground font-extrabold text-lg">L</span>
        <span className="absolute -right-1 -bottom-1 h-3 w-3 rounded-full bg-accent border-2 border-background" />
      </div>
      <span className="text-xl font-extrabold tracking-tight">Lokka</span>
    </div>
  );
}
